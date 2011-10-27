/*
Author:		Kyle Foreman
Created:	27 October 2011
Updated:	27 October 2011
Purpose:	redistribute garbage codes onto USCOD by county using a mixed effects regression
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in GC RD data
	import excel using "`projDir'/data/cod/raw/GC/garbageRedistribution.xlsx", clear sheet("Garbage") firstrow

// make a list of all the potential targets
	describe A_* B_* C_*, fullnames varlist
	local potentialTargets `r(varlist)'

// create a new variable that lists the targets for each GC
	generate targets = ""
	foreach t of local potentialTargets {
		replace targets = targets + "`t' " if `t' == 1
	}

// store the GC/targets for each package
	sort Order
	local numPackages = _N
	forvalues p = 1 / `numPackages' {
		local gc`p' = GC[`p']
		local targets`p' = targets[`p']
		local name`p' = Description[`p']
	}

// load in data
	use "`projDir'/data/cod/clean/deaths by USCOD/countyCFs.dta", clear

// loop through the sexes
	preserve
	foreach s in 1 2 {

	// loop through ICD versions
		foreach v in 9 10 {

		// set aside just the data for this sex/ICD
			keep if sex == `s' & icd == `v'

		// loop through each garbage redistribution package
			forvalues p = 1 / `numPackages' {

			// find the size of the target universe for this package
				generate universeProp = 0
				foreach t of local targets`p' {
					replace universeProp = universeProp + cf`t'
				}

			// for each target, calculate the logit of its proportion of the universe
				foreach t of local targets`p' {
					generate logitProp`t' = logit(clip(cf`t' / universeProp, .001, .999))
				}

			// loop through the targets of the current redistribution package
				foreach t of local targets`p' {
					di in red "Currently redistributing `name`p'' onto `t' for ICD `v' sex=`s'"

				// run the mixed effects regression
					xtmixed logitProp`t' year i.age || stateFips: || countyFips:

				// make predictions for this target
					predict xb, xb
					predict reState, reffects level(stateFips)
					bysort stateFips: egen reStateMean = mean(reState)
					replace reState = reStateMean if reState == .
					replace reState = 0 if reState == .
					predict reCounty, reffects level(countyFips)
					bysort countyFips: egen reCountyMean = mean(reCounty)
					replace reCounty = reCountyMean if reCounty == .
					replace reCounty = 0 if reCounty == .
					generate estProp`t' = invlogit(xb + reState + reCounty)
					drop xb reState reStateMean reCounty reCountyMean
				}

			// scale the targets so that they sum to 1
				egen totalEstProp = rowtotal(estProp*)
				foreach t of local targets`p' {
					replace estProp`t' = estProp`t' / totalEstProp
				}

			// redistribute the garbage code's CF onto the targets
				foreach t of local targets`p' {
					replace cf`t' = cf`t' + (estProp`t' * cf`gc`p'')
				}

			// set the garbage code to CF = 0
				replace cf`gc`p'' = 0
			}

		// save the redistributed data for this sex/icd version
			tempfile rd_`s'_`v'
			save `rd_`s'_`v'', replace
			restore, preserve
		}	
	}

// put all the redistributed pieces back together again
	clear
	foreach s in 1 2 {
		foreach v in 9 10 {
			append using `rd_`s'_`v''
		}
	}

// save the final results
	save "`projDir'/data/cod/clean/redistributed/countyCFs.dta"
