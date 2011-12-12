/*
Author:		Kyle Foreman
Created:	28 October 2011
Updated:	12 December 2011
Purpose:	make plots of garbage redistribution
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in redistributed deaths by state
	use "`projDir'/data/cod/clean/redistributed/redistributed.dta", clear
	keep if inrange(age, 0, 85) & underlying != "T"

// collapse down to national trends
	rename underlying uscod
	collapse (sum) deaths, by(uscod year)
	preserve

// add on unredistributed deaths by state
	use "`projDir'/data/cod/clean/deaths by USCOD/stateDeaths.dta", clear
	keep if inrange(age, 0, 85) & uscod != "T"
	collapse (sum) deaths, by(uscod year)
	rename deaths rawDeaths
	tempfile unrd
	save `unrd', replace
	restore
	merge 1:1 uscod year using `unrd', nogen

// add on cause names
	merge m:1 uscod using "`projDir'/data/cod/clean/COD Maps/USCOD_names.dta", keep(match) nogen
	generate name = uscod + " " + uscodName

// make a version without garbage codes and with aggregates
	preserve
	drop if substr(uscod, 1, 1) == "G"
	drop if length(uscod) == 3
	replace uscod = substr(uscod, 1, 3)
	collapse (sum) deaths rawDeaths, by(uscod year)
	tempfile lev2
	save `lev2', replace
	restore, preserve
	replace uscod = substr(uscod, 1, 1)
	collapse (sum) deaths rawDeaths, by(uscod year)
	tempfile lev1
	save `lev1', replace
	restore, preserve
	collapse (sum) deaths rawDeaths, by(year)
	generate uscod = ""
	tempfile all
	save `all', replace
	restore
	append using `lev2'
	append using `lev1'
	append using `all'
	drop name
	merge m:1 uscod using "`projDir'/data/cod/clean/COD Maps/USCOD_names.dta", update nogen keep(match master match_update)
	replace uscodName = "All Causes" if uscod == ""
	generate name = subinstr(uscod, "_", ".", .) + ". " + uscodName
	replace deaths = . if substr(uscod, 1, 1) == "G"
	scatter rawDeaths deaths year, by(name, yrescale legend(off)) xline(1998.5, lcolor(black)) xline(1988.5, lcolor(gray)) msymbol(oh oh) mcolor(red blue)
	graph export "`projDir'/outputs/data exploration/garbage/redistributed.pdf", replace
