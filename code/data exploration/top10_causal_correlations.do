/*
Author:		Kyle Foreman
Created:	13 January 2011
Updated:	13 January 2011
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
	replace age_group = "60plus" if age >= 60
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
	foreach a in "Under5" "5to14" "15to29" "30to44" "45to59" "60plus" {
		foreach s in 1 2 {
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
			forvalues i = 1/10 {
				replace top10 = 1 if underlying == "`r_`i''"
			}
			keep if top10
			drop top10

		// create rates
			generate rate_ = deaths / pop * 100000
			drop deaths pop

		// make causes wide
			reshape wide rate_, i(stateFips sex age_group) j(underlying) string

		// find pairwise correlations
			correlate rate_*
			matrix c = r(C)
			clear
			svmat2 c, names(col) rnames(cause)
			generate rank = 0
			generate name = ""
			order rank cause name
			local prev "name"
			forvalues i = 1/10 {
				local cs = subinstr("`r_`i''", "_", ".", .)
				replace rank = `i' if cause == "rate_`r_`i''"
				replace name = "`name_`r_`i'''" if cause == "rate_`r_`i''"
				replace cause = "`cs'" if cause == "rate_`r_`i''"
				label variable rate_`r_`i'' "`cs'  `name_`r_`i'''"
				order rate_`r_`i'', after(`prev')
				local prev "rate_`r_`i''"
			}
			sort rank
			export excel * using "`proj_dir'/outputs/data exploration/cause correlations/top10.xlsx", sheetreplace sheet("`sx'_`a'") firstrow(varlabels)
		}
	}
