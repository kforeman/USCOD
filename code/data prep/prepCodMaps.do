/*
Author:		Kyle Foreman
Created:	18 Oct 2011
Updated:	18 Oct 2011
Purpose:	create maps for ICD to CoD (using GBD codes as intermediaries)
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in the GBD cause list
	use "`projDir'/data/cod/raw/COD maps/GBD_hierarchy.dta", clear
	keep gbd_cause cause cause_name
	rename gbd_cause gbdCause

// collapse the gbd codes to something less detailed
	generate cod = ""
	generate codName = ""
	
	/* A. Communicable Diseases
		A.1 TB/HIV
		A.2 LRI
		A.3 Maternal
		A.4 Perinatal
		A.5 Other
	*/
		replace cod = "A" if cause == "A"
		replace codName = "Communicable Diseases" if cod == "A"
		replace cod = "A.1" if cause == "A01" | cause == "A02"
		replace codName = "TB/HIV" if cod == "A.1"
		replace cod = "A.2" if substr(cause,1,3) == "A15"
		replace codName = "LRI" if cod == "A.2"
		replace cod = "A.3" if substr(cause,1,3) == "A16"
		replace codName = "Maternal" if cod == "A.3"
		replace cod = "A.4" if substr(cause,1,3) == "A17"
		replace codName = "Perinatal" if cod == "A.4"
		replace cod = "A.5" if substr(cause,1,1) == "A" & cod == ""
		replace codName = "Other Communicable" if cod == "A.5"
	
	/* B. NCDs
		B.1 Cancer
			B.1.1 Lung Cancer
			B.1.2 Liver Cancer
			B.1.3 Breast Cancer
			B.1.4 Other Cancers
		B.2 Diabetes
		B.3 Cardiovascular
			B.3.1 IHD
			B.3.2 Stroke
			B.3.3 Other CVD
		B.4 Chronic Respiratory
		B.5 Cirrhosis
		B.6 Other NCD
	*/
		replace cod = "B" if cause == "B"
		replace codName = "Non-Communicable Diseases" if cod == "B"
		replace cod = "B.1" if cause == "B01"
		replace codName = "Cancer" if cod == "B.1"
		replace cod = "B.1.1" if substr(cause,1,5) == "B01.4"
		replace codName = "Lung Cancer" if cod == "B.1.1"
		replace cod = "B.1.2" if cause == "B01.3"
		replace codName = "Liver Cancer" if cod == "B.1.2"
		replace cod = "B.1.3" if cause == "B01.5"
		replace codName = "Breast Cancer" if cod == "B.1.3"
		replace cod = "B.1.4" if substr(cause,1,3) == "B01" & cod == ""
		replace codName = "Other Cancer" if cod == "B.1.4"
		replace cod = "B.2" if substr(cause,1,3) == "B02"
		replace codName = "Diabetes" if cod == "B.2"
		replace cod = "B.3" if cause == "B03"
		replace codName = "Cardiovascular" if cod == "B.3"
		replace cod = "B.3.1" if cause == "B03.2"
		replace codName = "IHD" if cod == "B.3.1"
		replace cod = "B.3.2" if substr(cause,1,5) == "B03.3"
		replace codName = "Stroke" if cod == "B.3.2"
		replace cod = "B.3.3" if substr(cause,1,3) == "B03" & cod == ""
		replace codName = "Other CVD" if cod == "B.3.3"
		replace cod = "B.4" if substr(cause,1,3) == "B04"
		replace codName = "Chronic Respiratory" if cod == "B.4"
		replace cod = "B.5" if cause == "B05"
		replace codName = "Cirrhosis" if cod == "B.5"
		replace cod = "B.6" if substr(cause,1,1) == "B" & cod == ""
		replace codName = "Other NCD" if cod == "B.6"
	
	/* C. Injuries
		C.1 Unintentional
			C.1.1 - RTI
			C.1.2 - Other Unintentional
		C.2 Intentional
			C.2.1 - Suicide
			C.2.2 - Homicide/War
	*/
		replace cod = "C" if cause == "C"
		replace codName = "Injuries" if cod == "C"
		replace cod = "C.1" if cause == "C01"
		replace codName = "Unintentional Injury" if cod == "C.1"
		replace cod = "C.1.1" if substr(cause,1,5) == "C01.1"
		replace codName = "RTI" if cod == "C.1.1"
		replace cod = "C.1.2" if substr(cause,1,3) == "C01" & cod == ""
		replace codName = "Other Unintentional Injury" if cod == "C.1.2"
		replace cod = "C.2" if cause == "C02"
		replace codName = "Intentional Injury" if cod == "C.2"
		replace cod = "C.2.1" if substr(cause,1,5) == "C02.1"
		replace codName = "Suicide" if cod == "C.2.1"
		replace cod = "C.2.2" if substr(cause,1,3) == "C02" & cod == ""
		replace codName = "Homicide/War" if cod == "C.2.2"

// save a map from GBD to CoD
	keep gbdCause cod codName
	drop if cod == ""
	save "`projDir'/data/cod/clean/COD maps/GBD_to_COD.dta", replace

// open ICD9
	use "`projDir'/data/cod/raw/COD maps/ICD9_to_GBD.dta", clear

// merge on CoD codes using GBD
	rename gbd_cause gbdCause
	merge m:1 gbdCause using "`projDir'/data/cod/clean/COD maps/GBD_to_COD.dta", nogen
	
// for now leave garbage codes as is
	replace cod = "GC" if cod == ""
	replace codName = "Garbage Code" if cod == "GC"

// it appears that the "E" is not included at the front of injury codes in the MCD data, so to be safe create versions both with and without the "E"
	preserve
	keep if substr(cause,1,1) == "E"
	replace cause = substr(cause,2,.)
	tempfile noE
	save `noE', replace
	restore
	append using `noE'

// there are a couple of extra HIV codes in US MCD that don't appear to be in Mohsen's map, so add those manually
	preserve
	keep if cause == "042"
	expand 31
	replace cause = "043" in 1
	forvalues i = 2 / 31 {
		replace cause = "04" + string(`i' + 18) in `i'
	}
	tempfile hiv
	save `hiv', replace
	restore
	append using `hiv'	

// keep just the important stuff
	keep cause cod codName
	drop if cause == ""

// save ICD9 to CoD
	save "`projDir'/data/cod/clean/COD maps/ICD9_to_COD.dta", replace

// open ICD10
	use "`projDir'/data/cod/raw/COD maps/ICD10_to_GBD.dta", clear

// set diabetes unspecified as diabetes
	replace gbd_cause = "G125" if substr(cause,1,3) == "E14"

// merge on CoD codes using GBD
	rename gbd_cause gbdCause
	merge m:1 gbdCause using "`projDir'/data/cod/clean/COD maps/GBD_to_COD.dta", nogen
	
// for now leave garbage codes as is
	replace cod = "GC" if cod == ""
	replace codName = "Garbage Code" if cod == "GC"

// keep just the important stuff
	keep cause cod codName
	drop if cause == ""

// save ICD10 to CoD
	save "`projDir'/data/cod/clean/COD maps/ICD10_to_COD.dta", replace

