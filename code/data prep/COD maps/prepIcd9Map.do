/*
Author:		Kyle Foreman
Created:	25 Oct 2011
Updated:	25 Oct 2011
Purpose:	create a stata merge map of ICD9 codes to USCOD
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in the ICD9 map
	import excel using "`projDir'/data/cod/raw/COD maps/ICD9and10_to_USCOD.xlsx", clear sheet("ICD9 to USCOD for stata") firstrow allstring
	rename USCOD uscod

// remove E prefix from injury codes
	replace cause = regexr(cause, "E", "")

// remove decimals from ICD codes
	replace cause = regexr(cause, "\.", "")

// remove duplicates
	duplicates drop cause uscod, force
	duplicates report

// save in Stata format
	compress
	save "`projDir'/data/cod/clean/COD maps/ICD9_to_USCOD.dta", replace
