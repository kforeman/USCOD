/*
Author:		Kyle Foreman
Created:	11 Nov 2011
Updated:	11 Nov 2011
Purpose:	plot correlations between causes over time
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in list of USCOD codes
	use "`projDir'/data/cod/clean/COD maps/USCOD_names.dta", clear
	drop if inlist(uscod, "A", "B", "B_1", "B_3", "C", "C_1", "C_2", "G")
	drop if substr(uscod, 1, 1) == "G"
	levelsof uscod, l(uscods) c
	foreach c of local uscods {
		levelsof uscodName if uscod == "`c'", l(`c'_name) c
	}
	count
	local numcods = `r(N)'

// load in the state data
	use "`projDir'/data/cod/clean/redistributed/stateDeaths.dta", clear

// add on population
	merge m:1 stateFips year sex age using "`projDir'/data/pop/clean/statePopulations.dta", keep(match)

// create rates
	generate rate = (deaths / pop) * 100000
	bysort stateFips year age sex: egen total_deaths = sum(deaths)
	generate cf = deaths / total_deaths

// reshape so causes are wide
	keep stateFips uscod year age sex rate cf
	reshape wide rate cf, i(stateFips year age sex) j(uscod) string

// make looping variables
	levelsof year, l(years) c
	tab year
	local numyears = `r(r)'
	levelsof sex, l(sexes) c
	tab sex
	local numsexes = `r(r)'
	levelsof age, l(ages) c
	tab age
	local numages = `r(r)'

// make empty matrices to store the data in
	local numrows = ((`numcods'^2)/2 + `numcods'/2) * `numsexes' * `numyears' * `numages'
	mata year = J(`numrows', 1, .)
	mata sex = J(`numrows', 1, .)
	mata age = J(`numrows', 1, .)
	mata cause1 = J(`numrows', 1, "")
	mata cause2 = J(`numrows', 1, "")
	mata rate_correlation = J(`numrows', 1, .)
	mata cf_correlation = J(`numrows', 1, .)

// loop through the years/sexes/ages
	preserve
	local counter = 0
	foreach y of local years {
		foreach s of local sexes {
			di "`y' `s'"
			foreach a of local ages {
				
			// keep just this unit's analysis data for now
				quietly keep if year == `y' & age == `a' & sex == `s'
			
			// loop through pairs of causes
				foreach c1 of local uscods {
					foreach c2 of local uscods {
						if ("`c1'" > "`c2'") continue
					
					// store the results in the matrices
						local counter = `counter' + 1
						mata year[`counter'] = `y'
						mata sex[`counter'] = `s'
						mata age[`counter'] = `a'
						mata cause1[`counter'] = "`c1'"
						mata cause2[`counter'] = "`c2'"
					
					// find the correlation between the causes
						quietly correlate rate`c1' rate`c2'
						mata rate_correlation[`counter'] = `r(rho)'
						quietly correlate cf`c1' cf`c2'
						mata cf_correlation[`counter'] = `r(rho)'
					}
				}
			
			// restore all the data for the next unit
				restore, preserve
			}
		}
	}

// save the results into stata
	restore, not
	clear
	getmata year sex age cause1 cause2 rate_correlation cf_correlation
	replace rate_correlation = 0 if rate_correlation == .
	replace cf_correlation = 0 if cf_correlation == .
	save "`projDir'/outputs/data exploration/cause correlations/pairwiseCorrelations.dta", replace

// save in wide format for the visualization
	generate pair = cause1 + "_" + cause2
	drop cause1 cause2
	rename rate_correlation rate_corr_
	rename cf_correlation cf_corr_
	reshape wide *corr_, i(year sex age) j(pair) string
	generate sexAge = "F" + string(age) if sex == 2
	replace sexAge = "M" + string(age) if sex == 1
	drop sex age
	outsheet using "`projDir'/outputs/data exploration/cause correlations/pairwiseCorrelations.csv", comma replace

// draw graphs for each cause
/*	set scheme tufte
	foreach c of local uscods {
		replace underlying = subinstr("`c' ``c'_name'", "_", ".", .) if underlying == "`c'"
	}
	capture mkdir "`projDir'/outputs/data exploration/multi cause/underlyingpdf"
	preserve
	foreach c of local uscods {
		keep if listedCause == "`c'"
		scatter underlyingProportion year, by(underlying, yrescale title("``c'_name' Anywhere in Part I")) xline(1998.5, lcolor(black)) xline(1988.5, lcolor(gray)) ytitle("Underlying Cause Proportion") xlabel(, labsize(small))
		graph export "`projDir'/outputs/data exploration/multi cause/underlyingpdf/`c'.pdf", replace
		restore, preserve
	}
	!"C:/ado/pdftk/pdftk.exe" "`projDir'/outputs/data exploration/multi cause/underlyingpdf/*.pdf" cat output "`projDir'/outputs/data exploration/multi cause/underlyingCause.pdf"
	!rmdir "`projDir'/outputs/data exploration/multi cause/underlyingpdf/" /q /s
*/
