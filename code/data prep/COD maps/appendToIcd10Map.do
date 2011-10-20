/*
Author:		Kyle Foreman
Created:	20 Oct 2011
Updated:	20 Oct 2011
Purpose:	add some additional MCD specific codes to Mohsen's ICD10 map
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in the ICD10 map
	use "`projDir'/data/cod/raw/COD maps/ICD10_to_GBD_Mohsen.dta", clear
	keep gbd_cause cause cause_name

// append the extra codes that aren't "official" ICD10 codes but are used in the US
	append using "`projDir'/data/cod/raw/COD maps/additional_ICD10_codes.dta"

// save ICD10 to GBD
	rename gbd_cause gbdCause
	rename cause_name causeName
	compress
	save "`projDir'/data/cod/raw/COD maps/ICD10_to_GBD.dta", replace
