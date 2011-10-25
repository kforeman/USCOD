/*
Author:		Kyle Foreman
Created:	25 Oct 2011
Updated:	25 Oct 2011
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

// save in Stata format
	compress
	save "`projDir'/data/cod/clean/COD maps/USCOD_names.dta", replace
