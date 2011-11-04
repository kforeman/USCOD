/*
Author:		Kyle Foreman
Created:	3 Nov 2011
Updated:	3 Nov 2011
Purpose:	make a heatmap of where we have cause of deaths registered
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in MCD data by county
	use "`projDir'/data/cod/clean/deaths by USCOD/countyDeaths.dta", clear

// transform into counts of where we have data
	generate hasDeaths = (deaths != .)
	collapse (count) hasDeaths, by(fips year)
	replace hasDeaths = 1 if hasDeaths

// reshape into a heatmap
	reshape wide hasDeaths, i(fips) j(year)

// merge on the master list of US counties
	merge 1:1 fips using "`projDir'/data/geo/clean/fipsMap.dta", nogen keepusing(fips state county)

// replace missings with zeros
	describe hasDeaths*, varlist
	foreach v in `r(varlist)' {
		replace `v' = 0 if `v' == .
	}

// sort for a heatmap
	order state county fips
	sort state county fips

// save the heatmap
	outsheet using "`projDir'/outputs/data exploration/data catalogs/mcdCountyCatalog.csv", comma replace

// make a state level heatmap
	generate stateFips = substr(fips, 1, 2)
	drop fips county state
	collapse (sum) hasDeaths*, by(state)
	preserve
	use "`projDir'/data/geo/clean/fipsMap.dta", clear
	keep state stateFips
	duplicates drop stateFips, force
	tempfile states
	save `states', replace
	restore
	merge 1:1 stateFips using `states', nogen
	describe hasDeaths*, varlist
	foreach v in `r(varlist)' {
		replace `v' = 0 if `v' == .
		replace `v' = 1 if `v' >= 1
	}
	order state stateFips
	sort state
	outsheet using "`projDir'/outputs/data exploration/data catalogs/mcdStateCatalog.csv", comma replace
