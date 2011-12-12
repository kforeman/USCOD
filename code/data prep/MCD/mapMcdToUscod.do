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
		replace uscod = "G_5" if uscod == ""

	// find counts of deaths by COD/age/sex/mcounty/year
		collapse (sum) deaths, by(uscod age sex mcounty year)
	
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

// split FIPS into state/county
	generate stateFips = substr(string(mcounty),1,2)
	generate countyFips = substr(string(mcounty),3,3)

// add ICD version variable
	generate icd = 9
	replace icd = 10 if year >= `icdSwitchYear'

// save deaths by county
	compress
	save "`projDir'/data/cod/clean/deaths by USCOD/countyDeaths.dta", replace
	preserve

// create cause fractions (wide) by county
	levelsof uscod, l(uscods) c
	reshape wide deaths, i(mcounty sex age year) j(uscod `uscods') string
	egen deathsTotal = rowtotal(deaths*)
	foreach u of local uscods {
		generate cf`u' = deaths`u' / deathsTotal
		replace cf`u' = 0 if cf`u' == .
	}
	keep mcounty countyFips stateFips sex age year icd deathsTotal cf*
	save "`projDir'/data/cod/clean/deaths by USCOD/countyCFs.dta", replace

// collapse to deaths by state
	restore
	collapse (sum) deaths, by(stateFips sex age year uscod)

// add ICD version variable
	generate icd = 9
	replace icd = 10 if year >= `icdSwitchYear'

// save causes of death by state
	save "`projDir'/data/cod/clean/deaths by USCOD/stateDeaths.dta", replace

// create cause fractions (wide) by state
	reshape wide deaths, i(stateFips sex age year) j(uscod `uscods') string
	egen deathsTotal = rowtotal(deaths*)
	foreach u of local uscods {
		generate cf`u' = deaths`u' / deathsTotal
		replace cf`u' = 0 if cf`u' == .
	}
	keep stateFips sex age year icd deathsTotal cf*
	save "`projDir'/data/cod/clean/deaths by USCOD/stateCFs.dta", replace
