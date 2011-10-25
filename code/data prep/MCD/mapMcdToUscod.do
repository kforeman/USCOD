/*
Author:		Kyle Foreman
Created:	18 Oct 2011
Updated:	25 Oct 2011
Purpose:	convert ICD to COD and save aggregated datasets by county/state
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup parameters specific to this code
	local startYear = 		1979
	local endYear = 		2007
	local icdSwitchYear =	1999

// loop through the years
	forvalues y = `startYear' / `endYear' {

	// load in the raw MCD file
		display in red _n "Loading `y'..." _n
		use "`projDir'/data/cod/clean/deaths by ICD/deaths`y'.dta", clear
	
	// convert ICD9 codes to COD
		if inrange( `y', `startYear', `icdSwitchYear'-1 ) {
			merge m:1 cause using "`projDir'/data/cod/clean/COD maps/ICD9_to_USCOD.dta", keep(match master)
		}
	
	// convert ICD10 codes to COD
		else if inrange( `y', `icdSwitchYear', `endYear') {
			merge m:1 cause using "`projDir'/data/cod/clean/COD maps/ICD10_to_USCOD.dta", keep(match master)
		}

	// any ICD codes that are missing from our map (i.e. are probably typos) put down as ill-defined
		replace uscod = "G.5" if uscod == ""

	// find counts of deaths by COD/age/sex/fips/year
		collapse (sum) deaths, by(uscod age sex fips year)
	
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
		collapse (sum) deaths, by(uscod year sex fips)
		generate age = 99
		tempfile allAges
		save `allAges', replace
	restore
	append using `allAges'

// split FIPS into state/county
	generate stateFips = substr(fips,1,2)
	generate countyFips = substr(fips,3,3)

// save causes of death by county
	save "`projDir'/data/cod/clean/deaths by USCOD/countyDeaths.dta", replace

// collapse to deaths by state
	collapse (sum) deaths, by(stateFips sex age year uscod)

// save causes of death by state
	save "`projDir'/data/cod/clean/deaths by USCOD/stateDeaths.dta", replace
