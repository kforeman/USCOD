/*
Author:		Kyle Foreman
Created:	18 Oct 2011
Updated:	18 Oct 2011
Purpose:	create population numbers by county and by state
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup parameters specific to this code
	local startYear = 	1979
	local endYear = 	2007

// loop through the years
	forvalues y = `startYear' / `endYear' {

	// load in the raw population file
		use "`projDir'/data/pop/raw/pop`y'.dta", clear

	// collapse across race
		collapse (sum) p*, by(sex fips)

	// make age long
		reshape long p, i(fips sex) j(age)
	
	// for now group all under 5s together, because we don't have infant breakdowns prior to 1990
		replace age = 0 if age < 5
		collapse (sum) p, by(sex fips age)
	
	// add in year
		generate year = `y'
	
	// cleanup variables to make consistent across datasets
		rename p pop
		tostring fips, replace
		replace fips = "0" + fips if length(fips) == 4
		label variable pop
		label variable age
	
	// save a tempfile for this year
		compress
		tempfile pop`y'
		save `pop`y'', replace
	}

// put the pieces together
	clear
	forvalues y = `startYear' / `endYear' {
		append using `pop`y''
	}

// add in total population across ages
	preserve
	collapse (sum) pop, by(year sex fips)
	generate age = 99
	tempfile allAges
	save `allAges', replace
	restore
	append using `allAges'

// split FIPS into state/county
	generate stateFips = substr(fips,1,2)
	generate countyFips = substr(fips,3,3)

// save the combined populations file by county
	save "`projDir'/data/pop/clean/countyPopulations.dta", replace

// collapse to state level populations
	collapse (sum) pop, by(stateFips sex age year)

// save populations by state
	save "`projDir'/data/pop/clean/statePopulations.dta", replace
