/*
Author:		Kyle Foreman
Created:	17 January 2011
Updated:	17 January 2011
Purpose:	prep the dataset necessary for the random effects model
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local proj_dir "D:/projects/`proj'"
	else local proj_dir "/shared/projects/`proj'"

// load in redistributed deaths
	use if inrange(age, 0, 85) & underlying != "T" using "`proj_dir'/data/cod/clean/redistributed/redistributed.dta", clear

// collapse down by state
	collapse (sum) deaths, by(stateFips age sex year underlying)
	
// square up
	fillin stateFips age sex year underlying
	replace deaths = 0 if _fillin

// add on population
	merge m:1 stateFips year sex age using "`proj_dir'/data/pop/clean/statePopulations.dta", nogen keep(match)
	
// combine into broader groups
	generate age_group = "Under5" if inrange(age, 0, 4)
	replace age_group = "5to14" if inrange(age, 5, 14)
	replace age_group = "15to29" if inrange(age, 15, 29)
	replace age_group = "30to44" if inrange(age, 30, 44)
	replace age_group = "45to59" if inrange(age, 45, 59)
	replace age_group = "60to74" if inrange(age, 60, 74)
	replace age_group = "75plus" if age >= 75
	drop if age_group == ""
	collapse (sum) deaths pop, by(stateFips age_group sex underlying year)

// round deaths for use in Poisson
	replace deaths = round(deaths)

// save it
	save "`proj_dir'/data/model inputs/state_random_effects_input.dta", replace
	outsheet using "`proj_dir'/data/model inputs/state_random_effects_input.csv", comma replace
