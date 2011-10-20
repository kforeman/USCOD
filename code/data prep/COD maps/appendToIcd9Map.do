/*
Author:		Kyle Foreman
Created:	20 Oct 2011
Updated:	20 Oct 2011
Purpose:	add some additional MCD specific codes to Mohsen's ICD9 map
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in the ICD9 map
	use "`projDir'/data/cod/raw/COD maps/ICD9_to_GBD_Mohsen.dta", clear
	keep gbd_cause cause cause_name

// append the extra codes that aren't "official" ICD9 codes but are used in the US
	// mostly new HIV codes and a few viral unspecified
	append using "`projDir'/data/cod/raw/COD maps/additional_ICD9_codes.dta"
	
// US MCD doesn't include the "E" prefix on injury codes, so add the prefixless versions to the map
	preserve
		keep if substr(cause,1,1) == "E"
		replace cause = regexr(cause, "E", "")
		tempfile noE
		save `noE', replace
	restore
	append using `noE'

// save ICD9 to GBD
	rename gbd_cause gbdCause
	rename cause_name causeName
	compress
	save "`projDir'/data/cod/raw/COD maps/ICD9_to_GBD.dta", replace
