/*
Author:		Kyle Foreman
Created:	3 Nov 2011
Updated:	3 Nov 2011
Purpose:	make a heatmap of where we do/don't have population data
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in population data by county
	use "`projDir'/data/pop/clean/countyPopulations.dta", clear

// transform into counts of where we have data
	generate hasPop = (pop != .)
	collapse (count) hasPop, by(fips year)

// reshape into a heatmap
	reshape wide hasPop, i(fips) j(year)

// merge on the master list of US counties
	merge 1:1 fips using "`projDir'/data/geo/clean/fipsMap.dta", nogen keepusing(fips state county)

// replace missings with zeros
	describe hasPop*, varlist
	foreach v in `r(varlist)' {
		replace `v' = 0 if `v' == .
	}

// create a totals column
	egen hasPopTotal = rowtotal(hasPop*)

// sort for a heatmap
	order state county fips
	sort state county fips

// save the heatmap
	outsheet using "`projDir'/outputs/data exploration/data catalogs/popCatalog.csv", comma replace
