/*
Author:		Kyle Foreman
Created:	16 January 2011
Updated:	16 January 2011
Purpose:	find spatial correlation of top 10 causes
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local proj_dir "D:/projects/`proj'"
	else local proj_dir "/shared/projects/`proj'"

// load in redistributed deaths
	use "`proj_dir'/data/cod/clean/redistributed/redistributed.dta", clear
	keep if inrange(age, 0, 85) & underlying != "T" & inrange(year, 2003, 2007)

// collapse down by state
	collapse (sum) deaths, by(stateFips age sex year underlying)

// add on population
	merge m:1 stateFips year sex age using "`proj_dir'/data/pop/clean/statePopulations.dta", nogen keep(match)
	
// combine into broader groups
	generate age_group = "Under5" if inrange(age, 0, 4)
	replace age_group = "5to14" if inrange(age, 5, 14)
	replace age_group = "15to29" if inrange(age, 15, 29)
	replace age_group = "30to44" if inrange(age, 30, 44)
	replace age_group = "45to59" if inrange(age, 45, 59)
	replace age_group = "60to74" if inrange(age, 60, 74)
	replace age_group = "75plus" if age >= 75
	drop if age_group == ""
	collapse (sum) deaths pop, by(stateFips age_group sex underlying)

// find cause names
	preserve
	use "`proj_dir'/data/cod/clean/COD maps/uscod_names.dta", clear
	levelsof uscod, l(causes) c
	foreach c of local causes {
		levelsof short_name if uscod == "`c'", l(name_`c') c
		local name_`c' = subinstr(upper("`name_`c''"), "_", " ", .)
	}
	restore

// save a tempfile (because there's a nested preserve/restore later on)
	tempfile dt
	save `dt', replace

// loop through age/sex
	foreach s in 1 2 {
		foreach a in "Under5" "5to14" "15to29" "30to44" "45to59" "60to74" "75plus" {
			use `dt', clear
			local sx = cond(`s'==1, "Male", "Female")
			keep if age_group == "`a'" & sex == `s'

		// keep top 10
			preserve
				collapse (sum) deaths, by(underlying)
				egen rank = rank(deaths), field
				forvalues i = 1/10 {
					levelsof underlying if rank == `i', l(r_`i') c
				}
			restore
			generate top10 = 0
			forvalues i = 1 / 10 {
				replace top10 = 1 if underlying == "`r_`i''"
			}
			keep if top10
			drop top10

		// make causes wide
			reshape wide deaths, i(stateFips sex age_group pop) j(underlying) string
		
		// loop through cause pairs
			forvalues c1 = 1 / 10 {
				forvalues c2 = 1 / 10 {
					if (`c1' > `c2') continue
				
				// initialize vector in which to store correlations
					mata rho = J(0, 1, .)
					
				// loop through a thousand draws to find uncertainty
					forvalues i = 1 / 1000 {
					
					// draw rates for each cause
						generate r1 = rbinomial(pop, (deaths`r_`c1'' / pop))
						generate r2 = rbinomial(pop, (deaths`r_`c2'' / pop))
					
					// find the correlation
						correlate r1 r2
					
					// store the correlation and get rid of temp vars
						mata rho = rho \ `r(rho)'
						drop r1 r2
					}
				
				// store the mean and lower/upper correlations for this pair
					mata st_numscalar("mean_`c1'_`c2'", mean(rho))
					mata st_numscalar("lo_`c1'_`c2'",   sort(rho, 1)[25])
					mata st_numscalar("hi_`c1'_`c2'",   sort(rho, 1)[975])
				}
			}
		
		// generate a matrix in which to put all the correlations
			clear
			set obs 10
			generate rank = _n
			generate cause = ""
			generate name = ""
			forvalues i = 1 / 10 {
				local cs = subinstr("`r_`i''", "_", ".", .)
				replace cause = "`cs'" in `i'
				replace name = "`name_`r_`i'''" in `i'
				generate corr_`i' = ""
				label variable corr_`i' "`cs'  `name_`r_`i'''"
			}
		
		// fill in the correlations
			forvalues c1 = 1 / 10 {
				forvalues c2 = 1 / 10 {
					if (`c1' > `c2') local val = string(round(mean_`c2'_`c1', .001)) + " [" + string(round(lo_`c2'_`c1', .001)) + ", " + string(round(hi_`c2'_`c1', .001)) + "]"
					else local val = string(round(mean_`c1'_`c2', .001)) + " [" + string(round(lo_`c1'_`c2', .001)) + ", " + string(round(hi_`c1'_`c2', .001)) + "]"
					replace corr_`c1' = "`val'" in `c2'
				}
			}

		// add to the excel spreadsheet
			export excel * using "`proj_dir'/outputs/data exploration/cause correlations/top10_with_uc.xlsx", sheetreplace sheet("`sx'_`a'") firstrow(varlabels)
		}
	}
