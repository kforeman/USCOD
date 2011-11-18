/*
Author:		Kyle Foreman
Created:	18 November 2011
Updated:	18 November 2011
Purpose:	prep data to be used in an epi transition by state model
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in redistributed cause of death data by county
	use "`projDir'/data/cod/clean/redistributed/redistributed.dta", clear
	keep if inrange(age, 0, 85) & sex != .

// aggregate by state and cause group
	generate uscod = substr(underlying, 1, 1)
	collapse (sum) deaths, by(stateFips sex uscod age year) fast

// add on total mortality
	preserve
	collapse (sum) deaths, by(stateFips sex age year) fast
	generate uscod = "T"
	tempfile tot
	save `tot', replace
	restore
	append using `tot'

// create broad age groups
	generate ageGroup = 0 if age < 15
	replace ageGroup = 15 if inrange(age, 15, 29)
	replace ageGroup = 30 if inrange(age, 30, 44)
	replace ageGroup = 45 if inrange(age, 45, 59)
	replace ageGroup = 60 if age >= 60
	collapse (sum) deaths, by(stateFips sex uscod ageGroup year) fast

// round off deaths
	replace deaths = round(deaths)

// fill in the dataset, ensuring there's 0s put in for any cause not observed in a state/age/year/sex
	fillin sex uscod year stateFips ageGroup
	replace deaths = 0 if deaths == . | _fillin
	drop _fillin

// prep population
	preserve
	use "`projDir'/data/pop/clean/statePopulations.dta", clear
	generate ageGroup = 0 if age < 15
	replace ageGroup = 15 if inrange(age, 15, 29)
	replace ageGroup = 30 if inrange(age, 30, 44)
	replace ageGroup = 45 if inrange(age, 45, 59)
	replace ageGroup = 60 if age >= 60
	collapse (sum) pop, by(stateFips sex ageGroup year) fast
	tempfile pop
	save `pop', replace
	restore
	merge m:1 stateFips ageGroup sex year using `pop', keep(match) nogen

// clean up some variables, sort, etc
	rename ageGroup age_group
	rename stateFips state
	rename uscod cause
	destring state, replace
	order state year sex age cause deaths pop
	sort state year sex age cause

// save the prepped data for mapping
	compress
	save "`projDir'/data/model inputs/epi_transition_by_state.dta", replace
	outsheet using "`projDir'/data/model inputs/epi_transition_by_state.csv", comma replace
