/*
Author:		Kyle Foreman
Created:	25 Oct 2011
Updated:	25 Oct 2011
Purpose:	create a stata merge map of ICD10 codes to USCOD
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in the ICD10 map
	import excel using "`projDir'/data/cod/raw/COD maps/ICD9and10_to_USCOD.xlsx", clear sheet("ICD10 to USCOD for stata") firstrow allstring
	rename USCOD uscod

// remove decimals from ICD codes
	replace cause = regexr(cause, "\.", "")

// remove duplicates
	drop if uscod == "0"
	duplicates drop cause uscod, force
	duplicates report

// get rid of excess spaces
	replace cause = trim(cause)

// save in Stata format
	compress
	save "`projDir'/data/cod/clean/COD maps/ICD10_to_USCOD.dta", replace
	outsheet using "`projDir'/data/cod/clean/COD maps/ICD10_to_USCOD.csv", comma replace
