/*
Author:		Kyle Foreman
Created:	20 October 2011
Updated:	20 October 2011
Purpose:	Make a list of the most prevalent garbage codes for ICD9 and ICD10
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup locals necessary for this code
	local icd9Start 	= 1979
	local icd9End 		= 1998
	local icd10Start 	= 1999
	local icd10End 		= 2007

// create garbage tallies for ICD9
	clear
	di in red "Beginning ICD9 analysis..."

	// load in the CoD data
		forvalues y = `icd9Start' / `icd9End' {
			append using "`projDir'/data/cod/clean/deaths by ICD/deaths`y'.dta"
		}
		compress
		keep if inrange(age, 0, 85)

	// collapse by ICD/age/sex
		collapse (sum) deaths, by(sex age cause)

	// map on GBD codes
		merge m:1 cause using "`projDir'/data/cod/raw/COD maps/ICD9_to_GBD.dta", keep(match) nogen

	// find proportion of each ICD code by age/sex
		bysort age sex: egen prop_ = pc(deaths), prop
	
	// reshape for a heatmap
		generate ageSex = string(age) + "_M" if sex == 1
		replace ageSex = string(age) + "_F" if sex == 2
		drop if gbdCause != "G999"
		drop age sex deaths gbdCause
		reshape wide prop_, i(cause causeName) j(ageSex) str

	// sort by average garbage percentage
		egen sortme = rowmean(prop_*)
		gsort - sortme
		drop sortme
		
	// save the heatmap
		outsheet using "`projDir'/outputs/data exploration/garbage/icd9_garbage_list.csv", comma replace
		
// create garbage tallies for ICD10
	clear
	di in red "Beginning ICD10 analysis..."

	// load in the CoD data
		forvalues y = `icd10Start' / `icd10End' {
			append using "`projDir'/data/cod/clean/deaths by ICD/deaths`y'.dta"
		}
		compress
		keep if inrange(age, 0, 85)

	// collapse by ICD/age/sex
		collapse (sum) deaths, by(sex age cause)

	// map on GBD codes
		merge m:1 cause using "`projDir'/data/cod/raw/COD maps/ICD10_to_GBD.dta", keep(match) nogen

	// find proportion of each ICD code by age/sex
		bysort age sex: egen prop_ = pc(deaths), prop
	
	// reshape for a heatmap
		generate ageSex = string(age) + "_M" if sex == 1
		replace ageSex = string(age) + "_F" if sex == 2
		drop if gbdCause != "G999"
		drop age sex deaths gbdCause
		reshape wide prop_, i(cause causeName) j(ageSex) str

	// sort by average garbage percentage
		egen sortme = rowmean(prop_*)
		gsort - sortme
		drop sortme
		
	// save the heatmap
		outsheet using "`projDir'/outputs/data exploration/garbage/icd10_garbage_list.csv", comma replace
