/*
Author:		Kyle Foreman
Created:	18 Oct 2011
Updated:	19 Oct 2011
Purpose:	create cause of death numbers by county and state from MCD data
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup parameters specific to this code
	local startYear = 	1979
	local endYear = 	2007

// in order to use Sandeep's code for fixing FIPS codes, need to specify where all his stuff is located
	global merge "`projDir'/data/geo/raw/sandeeps merge maps/"

// loop through the years
	forvalues y = `startYear' / `endYear' {

	// load in the raw MCD file
		display in red _n "Loading `y'..." _n
		use "`projDir'/data/cod/raw/MCD micro/mcd`y'.dta", clear

	// convert age to the correct format
		quietly {
			generate age = .
			replace age = 0 if inlist(substr(age_detail,1,1), "2", "3", "4", "5", "6")
			if `y' >= 2003 {
				replace age = floor(real(substr(age_detail,2,3))/5)*5 if substr(age_detail,1,1) == "1"
				replace age = 85 if (age > 85 & age != .)
			}
			else { 
				replace age = floor(real(substr(age_detail,2,2))/5)*5 if substr(age_detail,1,1) == "0"
				replace age = 85 if substr(age_detail,1,1) == "1" | (age > 85 & age != .)
			}
		}

	// use Sandeep's code to convert to appropriate FIPS codes
		quietly do "$merge/sandeepsFipsFixer.do" `y'
	
	// convert ICD9 codes to COD
		if inrange( `y', 1979, 1998 ) {
			rename icd9 cause
			merge m:1 cause using "`projDir'/data/cod/clean/COD maps/ICD9_to_COD.dta", keep(match)
		}
	
	// convert ICD10 codes to COD
		else if `y' >= 1999 {
			if inrange( `y', 1999, 2001) rename icd10 cause
			merge m:1 cause using "`projDir'/data/cod/clean/COD maps/ICD10_to_COD.dta", keep(match)
		}

	// make sure sex is in the right format
		capture confirm numeric variable sex
		quietly {
			if _rc {
				rename sex sexStr
				generate sex = .
				replace sex = 1 if sexStr == "M"
				replace sex = 2 if sexStr == "F"
				drop sexStr
			}
			else replace sex = . if !inlist( sex, 1, 2 )
		}

	// find counts of deaths by cause/age/sex/fips
		quietly generate deaths = 1
		collapse (count) deaths, by(cod age sex fips)
	
	// add year to the data
		quietly generate year = `y'
	
	// save a tempfile for this year
		quietly compress
		tempfile cod`y'
		save `cod`y'', replace
	}

// put the pieces together
	clear
	forvalues y = `startYear' / `endYear' {
		append using `cod`y''
	}

// add in total deaths across ages
	preserve
	collapse (sum) deaths, by(cod year sex fips)
	generate age = 99
	tempfile allAges
	save `allAges', replace
	restore
	append using `allAges'

// split FIPS into state/county
	generate stateFips = substr(fips,1,2)
	generate countyFips = substr(fips,3,3)

// save causes of death by county
	save "`projDir'/data/cod/clean/deaths/countyDeaths.dta", replace

// collapse to deaths by state
	collapse (sum) deaths, by(stateFips sex age year cod)

// save causes of death by state
	save "`projDir'/data/cod/clean/deaths/stateDeaths.dta", replace
