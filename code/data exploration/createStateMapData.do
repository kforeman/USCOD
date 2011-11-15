/*
Author:		Kyle Foreman
Created:	15 November 2011
Updated:	15 November 2011
Purpose:	find state death rates by cause/age/sex
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup params
	clear
	set mem 5g
	set maxvar 30000

// load in redistributed cause of death data by county
	use "`projDir'/data/cod/clean/redistributed/redistributed.dta", clear
	keep if inrange(age, 0, 85) & sex != .
	rename underlying uscod

// aggregate by state
	collapse (sum) deaths, by(stateFips sex uscod age year) fast

// add on population
	merge m:1 stateFips age sex year using "`projDir'/data/pop/clean/statePopulations.dta", keep(match) nogen

// create broad age groups
	generate ageGroup = "0to14" if age < 15
	replace ageGroup = "15to29" if inrange(age, 15, 29)
	replace ageGroup = "30to44" if inrange(age, 30, 44)
	replace ageGroup = "45to59" if inrange(age, 45, 59)
	replace ageGroup = "60plus" if age >= 60
	collapse (sum) deaths pop, by(stateFips sex uscod ageGroup year) fast

// create rates
	generate rate_ = deaths / pop * 100000

// reshape
	generate asyc = ageGroup + "_" + string(sex) + "_" + string(year) + "_" + uscod
	keep asyc stateFips rate_
	reshape wide rate_, i(stateFips) j(asyc) string

// replace missing with zero
	describe rate_*, varlist
	foreach v in `r(varlist)' {
		replace `v' = 0 if `v' == .
	}

// save the prepped data for mapping
	outsheet using "`projDir'/outputs/data exploration/mapping/state_rates.csv", comma replace
