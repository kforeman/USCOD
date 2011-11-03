/*
Author:		Kyle Foreman
Created:	18 Oct 2011
Updated:	18 Oct 2011
Purpose:	create a map to convert from FIPS to state/county
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in the zipcodes file
	use "`projDir'/data/geo/raw/zipcodes.dta", clear

// keep just relevant variables
	keep state county_name state_fips county_fips

// rename to get rid of underscores
	rename state_fips stateFips
	rename county_fips countyFips
	rename county_name county

// convert to strings to maintain leading zeroes
	tostring stateFips countyFips, replace
	replace stateFips = "0" + stateFips if length(stateFips) == 1
	replace countyFips = "00" + countyFips if length(countyFips) == 1
	replace countyFips = "0" + countyFips if length(countyFips) == 2

// generate the combined fips code
	generate fips = stateFips + countyFips

// get rid of duplicate fips
	duplicates drop fips, force

// get rid of non-states
	drop if inlist(state, "AE", "AS", "FM", "GU", "MH", "MP", "PR", "PW", "VI")

// cleanup county names
	replace county = proper(county)

// save the map
	save "`projDir'/data/geo/clean/fipsMap.dta", replace
