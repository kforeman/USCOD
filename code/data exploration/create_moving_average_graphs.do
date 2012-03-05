/*
Author:		Kyle Foreman
Created:	02 Mar 2011
Updated:	02 Mar 2011
Purpose:	create moving averages by disease/region for broader age groups
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local proj_dir "D:/projects/`proj'"
	else local proj_dir "/shared/projects/`proj'"

// find cause names
	insheet using "`proj_dir'/data/cod/clean/COD maps/uscod_for_menus.csv", comma clear
	levelsof uscod, l(uscods) c
	foreach c of local uscods {
		levelsof uscodname if uscod == "`c'", l(`c'_name) c
	}

// load in the dataset 
	use if inrange(age, 0, 85) & underlying != "T" using "`proj_dir'/data/cod/clean/redistributed/redistributed.dta", clear

// collapse down by state
	collapse (sum) deaths, by(stateFips age sex year underlying)
	
// square up
	fillin stateFips age sex year underlying
	replace deaths = 0 if _fillin

// combine into broader groups
	generate age_group = "35to64" if inrange(age, 35, 64)
	replace age_group =  "65plus" if age >= 65
	drop if age_group == ""
	collapse (sum) deaths, by(stateFips age_group sex underlying year)

// cleanup data	
	rename underlying cause
	rename stateFips state
	rename age_group age
	
// save the most detailed level
	tempfile level3
	save `level3', replace
	
// next level
	replace cause = substr(cause, 1, 3)
	collapse (sum) deaths, by(year sex cause age state)
	tempfile level2
	save `level2', replace
	
// and the highest (just A/B/C)
	replace cause = substr(cause, 1, 1)
	collapse (sum) deaths, by(year sex cause age state)
	tempfile level1
	save `level1', replace
	
// finally total deaths
	replace cause = "T"
	collapse (sum) deaths, by(year sex cause age state)
	replace deaths = round(deaths)
	
// put them back together
	append using `level3'
	append using `level2'
	append using `level1'
	duplicates drop

// add national results
	tempfile state_results
	save `state_results', replace
	collapse (sum) deaths, by(year sex cause age)
	generate state = "00"
	append using `state_results'

// create five year moving average
	egen id = group(cause sex age state)
	tsset id year
	tssmooth ma smooth = deaths, window(2 1 2)
	drop deaths
	rename smooth deaths

// make year wide
	reshape wide deaths, i(sex cause age state) j(year)

// save deaths
	outsheet using "`proj_dir'/outputs/data exploration/moving averages/deaths.csv", comma replace
	keep if state == "00"
	outsheet using "`proj_dir'/outputs/data exploration/moving averages/deaths_national.csv", comma replace

// get population into the same format
	use if age<= 85 using "`proj_dir'/data/pop/clean/statePopulations.dta", clear
	generate age_group = "35to64" if inrange(age, 35, 64)
	replace age_group =  "65plus" if age >= 65
	drop if age_group == ""
	collapse (sum) pop, by(stateFips age_group sex year)
	reshape wide pop, i(stateFips age_group sex) j(year)
	rename stateFips state
	rename age_group age

// add on national pop
	tempfile state_pop
	save `state_pop', replace
	collapse (sum) pop*, by(sex age)
	generate state = "00"
	append using `state_pop'

// save populations
	outsheet using "`proj_dir'/outputs/data exploration/moving averages/pop.csv", comma replace
	keep if state == "00"
	outsheet using "`proj_dir'/outputs/data exploration/moving averages/pop_national.csv", comma replace

// create region/state lookups
	use "`proj_dir'/data/geo/raw/sandeeps merge maps/USBEA_regions.dta", clear
	tostring statefip, generate(state)
	replace state = "0" + state if statefip < 10
	drop statefip
	rename hsastate state_abbr
	decode usbearegion, generate(region)
	drop usbearegion
	local N = _N+1
	set obs `N'
	replace state = "00" in `N'
	replace state_abbr = "US" in `N'
	replace state_name = "National" in `N'
	replace region = "National" in `N'
	outsheet using "`proj_dir'/outputs/data exploration/moving averages/states.csv", comma replace

// create cause list
	insheet using "`proj_dir'/data/cod/clean/COD maps/uscod_for_menus.csv", comma clear
	rename uscod cause
	rename uscodname name
	rename short_sweet short
	drop menu_name
	drop short_name
	rename order sort_order
	generate leaf = inlist(cause, "A_1", "A_2", "A_3", "A_4", "A_5", "A_6", "B_1_1", "B_1_2", "B_1_3") | inlist(cause, "B_1_4", "B_1_5", "B_1_6", "B_2", "B_3_1", "B_3_2", "B_3_3", "B_4", "B_5") | inlist(cause, "B_6", "B_7", "C_1_1", "C_1_2", "C_2_1", "C_2_2")
	outsheet using "`proj_dir'/outputs/data exploration/moving averages/causes.csv", comma replace
