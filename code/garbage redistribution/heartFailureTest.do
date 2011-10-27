/*
Author:		Kyle Foreman
Created:	26 October 2011
Updated:	26 October 2011
Purpose:	test redistribution regression idea on HF
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup parameters specific to this code
	local icdShiftYear =	1999
	local targetList 		B_3_1 B_3_3
	local garbage	 		G_2

// load in data
	use "`projDir'/data/cod/clean/deaths by USCOD/countyCFs.dta", clear

// for now just use ICD9 males
	keep if year < `icdShiftYear' & sex == 1 & age != .

// find the size of the target universe
	generate universeCf = 0
	foreach t of local targetList {
		replace universeCf = universeCf + cf`t'
	}

// find cause fractions as percentages of the universe
	foreach t of local targetList {
		generate logitProp`t' = logit(clip(cf`t' / universeCf, .001, .999))
	}

// loop through the targets
	foreach t of local targetList {
		di in red "Currently redistributing `garbage' onto `t'"
	
	// run a mixed effects regression to predict the logit CF of each target
		xtmixed logitProp`t' year i.age || stateFips: || countyFips:
	
	// make predictions for this target
		predict xb`t', xb
		predict reState`t', reffects level(stateFips)
		bysort stateFips: egen reStateMean`t' = mean(reState`t')
		replace reState`t' = reStateMean`t' if reState`t' == .
		replace reState`t' = 0 if reState`t' == .
		predict reCounty`t', reffects level(countyFips)
		bysort countyFips: egen reCountyMean`t' = mean(reCounty`t')
		replace reCounty`t' = reCountyMean`t' if reCounty`t' == .
		replace reCounty`t' = 0 if reCounty`t' == .
		generate estProp`t' = invlogit(xb`t' + reState`t' + reCounty`t')
	}

// scale the targets so that they sum to 1
	egen totalEstProp = rowtotal(estProp*)
	foreach t of local targetList {
		replace estProp`t' = estProp`t' / totalEstProp
	}

// redistribute the garbage code's CF onto the targets
	foreach t of local targetList {
		replace cf`t' = cf`t' + (estProp`t' * cf`garbage')
	}
	replace cf`garbage' = 0
	

