/*
Author:		Kyle Foreman
Created:	25 October 2011
Updated:	25 October 2011
Purpose:	make rough plots of ICD discontinuities
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in cause of death data by state
	use "`projDir'/data/cod/clean/deaths by USCOD/stateDeaths.dta", clear
	keep if inrange(age, 0, 85)

// collapse down to national trends
	collapse (sum) deaths, by(uscod year)

// plot national trends
	scatter deaths year, by(uscod, compact yrescale)
		
// save the graph
	graph export "`projDir'/outputs/data exploration/garbage/icdDiscontinuities.pdf", replace
