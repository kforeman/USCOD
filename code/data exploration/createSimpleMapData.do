/*
Author:		Kyle Foreman
Created:	1 November 2011
Updated:	1 November 2011
Purpose:	find average death rates by cause for really broad age/decade groups for a county map
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in redistributed cause of death data by county
	use "`projDir'/data/cod/clean/redistributed/countyDeaths.dta", clear
	keep if inrange(age, 0, 85)

// add on population
/* Note: we're dropping a lot of observations here, probably need to go back and look over the population prep code some more */
	merge m:1 fips age sex year using "`projDir'/data/pop/clean/countyPopulations.dta", keep(match)

// create broad age groups
	generate ageGroup = "0to14" if age < 15
	replace ageGroup = "15to29" if inrange(age, 15, 29)
	replace ageGroup = "30to44" if inrange(age, 30, 44)
	replace ageGroup = "45to59" if inrange(age, 45, 59)
	replace ageGroup = "60plus" if age >= 60

// group by decades (approximately)
	generate decade = 1980 if inrange(year, 1979, 1989)
	replace decade = 1990 if inrange(year, 1980, 1999)
	replace decade = 2000 if inrange(year, 1990, 2007)

// find deaths by these broad groups
	collapse (sum) deaths pop, by(uscod sex ageGroup decade fips)

// find death rate
	generate rate = deaths / pop * 100000
	drop if rate == .

// save the prepped data for mapping
	outsheet using "`projDir'/outputs/data exploration/mapping/roughRates.csv", comma replace

