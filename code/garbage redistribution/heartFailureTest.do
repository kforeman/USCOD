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
	local targetList 		"B.3.1", "B.3.2", "B.3.3"
	local garbage	 		"G.2"

// load in data
	use "`projDir'/data/cod/clean/deaths by USCOD/stateDeaths.dta", clear

// for now just use ICD9 males
	keep if year < `icdShiftYear' & sex == 1 & age != .

// reshape wide


// isolate "universe of heart failure" deaths
	generate target = inlist(uscod, "`targetList'")
	levelsof uscod if target, l(targets) c
	generate garbage = "`garbage'"
	keep if target | garbage

// switch targets to cause fractions
	bysort sex age year stateFips: egen cf = pc(deaths) if target, prop
	generate logitCf = logit(cf)

// loop through the targets
	foreach t of local targets {
		local tg = strtoname( "`t'" )
	
	// run a mixed effects regression to predict the logit CF of each target
		xtmixed logitCf year i.age || stateFips: if uscod == "`t'"
	
	// make predictions for this cause
		predict xb_`tg', xb
		predict re_`tg', reff
		replace re_`tg' = 0 if re_`tg' == .
		generate estCf_`tg' = invlogit(xb_`tg' + re_`tg')
	}

// scale the targets so that they sum to 1
	egen totalEstCf = rowtotal(estCf_*)
	foreach t of local targets {
		local tg = strtoname( "`t'" )
		
	}



