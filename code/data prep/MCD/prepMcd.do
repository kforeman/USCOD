/*
Author:		Kyle Foreman
Created:	18 Oct 2011
Updated:	25 Oct 2011
Purpose:	create cause of death numbers by county/age/sex/year/ICD from MCD data
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup parameters specific to this code
	local startYear = 		1991
	local endYear = 		2007
	local icdSwitchYear =	1999

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
		quietly do "`projDir'/code/data prep/geo/sandeepsFipsFixer.do" `y'

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
		if inrange( `y', `startYear', `icdSwitchYear'-1) rename icd9 cause
		else if inrange( `y', `icdSwitchYear', 2001) rename icd10 cause

	// make a column to count how many deaths there are
		quietly generate deaths = 1

	// for now, replace mcounty with state + 999 for those places in which county is missing (1991-1997)
		if inrange(`y', 1991, 1997) replace mcounty = real(stateres_fips + "999")

	// find counts of deaths by cause/age/sex/fips
		collapse (sum) deaths, by(cause age sex mcounty)
		summarize deaths if mcounty != ., meanonly
		local deaths`y' = `r(sum)'
		di in green "`deaths`y'' Deaths" _n
	
	// add year to the data
		quietly generate year = `y'
	
	// save the prepped data for this year
		keep cause age sex mcounty deaths year
		quietly compress
		quietly save "`projDir'/data/cod/clean/deaths by ICD/deaths`y'.dta", replace
	}

// print out how many deaths in total for each year, for easier debugging
	di in red "Year    Total deaths"
	forvalues y = `startYear' / `endYear' {
		di in green "`y'    `deaths`y''"
	}
