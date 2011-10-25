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

// add on cause names
	merge m:1 uscod using "`projDir'/data/cod/clean/COD Maps/USCOD_names.dta", keep(match)
	generate name = uscod + " " + uscodName

// plot national trends
	scatter deaths year, by(name, compact yrescale) xline(1998.5)

// save the graph
	graph export "`projDir'/outputs/data exploration/garbage/icdDiscontinuities.pdf", replace
