/*
Author:		Kyle Foreman
Created:	25 October 2011
Updated:	13 December 2011
Purpose:	create a stata merge map of USCOD names
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in the ICD9 map
	import excel using "`projDir'/data/cod/raw/COD maps/ICD9and10_to_USCOD.xlsx", clear sheet("USCOD") firstrow allstring
	rename USCOD uscod
	rename USCOD_name uscodName

// add in a code for the total (T)
	local newobs = _N + 1
	set obs `newobs'
	replace uscod = "T" in `newobs'
	replace uscodName = "Total" in `newobs'
	replace short_name = "all" in `newobs'

// save in Stata format
	compress
	save "`projDir'/data/cod/clean/COD maps/USCOD_names.dta", replace

// save a csv
	outsheet using "`projDir'/data/cod/clean/COD maps/USCOD_names.csv", comma replace

// make a version for menus
	drop if substr(uscod, 1, 1) == "G"
	generate menu_name = subinstr(uscod, "_", ".", .) + ". " + uscodName
	replace menu_name = "  " + menu_name if length(uscod) == 1
	replace menu_name = "    " + menu_name if length(uscod) == 3
	replace menu_name = "      " + menu_name if length(uscod) == 5
	replace menu_name = "Total Mortality" if uscod == "T"
	sort uscod
	generate order = _n
	replace order = 0 if uscod == "T"
	sort order
	outsheet using "`projDir'/data/cod/clean/COD maps/uscod_for_menus.csv", comma replace
