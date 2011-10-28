/*
Author:		Kyle Foreman
Created:	28 October 2011
Updated:	28 October 2011
Purpose:	make plots of garbage redistribution
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in redistributed deaths by state
	use "`projDir'/data/cod/clean/redistributed/stateDeaths.dta", clear
	keep if inrange(age, 0, 85)

// collapse down to national trends
	collapse (sum) deaths, by(uscod year)
	preserve

// add on unredistributed deaths by state
	use "`projDir'/data/cod/clean/deaths by USCOD/stateDeaths.dta", clear
	keep if inrange(age, 0, 85)
	collapse (sum) deaths, by(uscod year)
	rename deaths rawDeaths
	tempfile unrd
	save `unrd', replace
	restore
	merge 1:1 uscod year using `unrd', nogen

// add on cause names
	merge m:1 uscod using "`projDir'/data/cod/clean/COD Maps/USCOD_names.dta", keep(match)
	generate name = uscod + " " + uscodName

// plot national trends
	set scheme tufte
	scatter rawDeaths deaths year, by(name, yrescale legend(off)) xline(1998.5) msymbol(oh oh) mcolor(red blue)

// save the graph
	graph export "`projDir'/outputs/data exploration/garbage/redistributed.pdf", replace
