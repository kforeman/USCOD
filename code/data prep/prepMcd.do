/*
Author:		Kyle Foreman
Created:	18 Oct 2011
Updated:	19 Oct 2011
Purpose:	create cause of death numbers by county/age/sex/year/ICD from MCD data
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
		quietly do "`projDir'/code/data prep/sandeepsFipsFixer.do" `y'

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

	// rename the ICD code variable to "cause"
		if inrange( `y', 1979, 1998 ) rename icd9 cause
		else if inrange( `y', 1999, 2001) rename icd10 cause

	// make a column to count how many deaths there are
		quietly generate deaths = 1

	// find counts of deaths by cause/age/sex/fips
		collapse (sum) deaths, by(cause age sex fips)
	
	// add year to the data
		quietly generate year = `y'
	
	// save the prepped data for this year
		keep cause age sex fips deaths year
		quietly compress
		save "`projDir'/data/cod/clean/deaths by ICD/deaths`y'.dta", replace
	}
