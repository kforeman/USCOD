/*
Author:		Kyle Foreman
Created:	19 October 2011
Updated:	19 October 2011
Purpose:	Check how much garbage there is by age/year and state/year
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in cause of death data by state
	use "`projDir'/data/cod/clean/deaths/stateDeaths.dta", clear
	keep if inrange(age, 0, 85)

// find garbage/non-garbage deaths by state/age/year
	replace cod = "OK" if cod != "GC"
	collapse (sum) deaths, by(stateFips year age cod)

// first do garbage by age/year
	preserve
	collapse (sum) deaths, by(year age cod)
	
	// find proportion of garbage
		bysort year age: egen garbage_ = pc(deaths), prop
		keep if cod == "GC"
	
	// reshape into a heatmap
		drop deaths cod
		reshape wide garbage_, i(age) j(year)
	
	// save the heatmap
		outsheet using "`projDir'/outputs/data exploration/garbage/garbage heatmap by age.csv", comma replace

// then do garbage by state/year
	restore
	collapse (sum) deaths, by(year stateFips cod)
	
	// find proportion of garbage
		bysort year stateFips: egen garbage_ = pc(deaths), prop
		keep if cod == "GC"
		
	// reshape into a heatmap
		drop deaths cod
		reshape wide garbage_, i(stateFips) j(year)
	
	// add on state postal codes
		preserve
			use "`projDir'/data/geo/clean/fipsMap.dta", clear
			duplicates drop stateFips, force
			tempfile states
			save `states', replace
		restore
		merge 1:m stateFips using `states', keep(match) keepusing(state) nogen
		drop stateFips
		order state
		
	// save the heatmap
		outsheet using "`projDir'/outputs/data exploration/garbage/garbage heatmap by state.csv", comma replace
