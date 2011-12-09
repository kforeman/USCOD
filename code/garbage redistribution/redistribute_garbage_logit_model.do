/*
Author:		Kyle Foreman
Created:	27 October 2011
Updated:	10 November 2011
Purpose:	test new method of redistributing garbage
Inputs:		parameter 1: garbage code
			parameter 2: icd version
			parameter 3: sex
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup locals for this particular code
	local icdSwitchYear = 1999

// log the regression results
	log using "`projDir'/logs/scratch/icd`2'Sex`3'GC`1'.smcl", replace
	di in red "Running redistribution algorithms for ICD `2', sex `3', GC `1'" _n

// load in cause list
	use "`projDir'/data/cod/clean/COD maps/USCOD_names.dta", clear
	drop if inlist(uscod, "A", "B", "B_1", "B_3", "C", "C_1", "C_2", "G", "T")
	drop if substr(uscod, 1, 1) == "G"
	levelsof uscod, l(uscods) c

// load in list of garbage targets for this code
	import excel using "`projDir'/data/cod/raw/GC/garbageRedistribution.xlsx", clear sheet("Garbage") firstrow

// create a new variable that lists the targets for this GC
	generate targets = ""
	foreach t of local uscods {
		if substr("`t'", 1, 1) == "G" continue
		replace targets = targets + "`t' " if `t' == 1
	}
	keep if GC == "`1'"
	local targets = targets[1]

// load in data
	if `2' == 9 use if sex == `3' & year < `icdSwitchYear' & (`1' == 1 | underlying == "`1'") using "`projDir'/data/cod/clean/garbage inputs/matchingTestDataset.dta", clear
	else if `2' == 10 use if sex == `3' & year >= `icdSwitchYear' & (`1' == 1 | underlying == "`1'") using "`projDir'/data/cod/clean/garbage inputs/matchingTestDataset.dta", clear

// just write the temp file if this garbage code is non-existent for this sex/icd
	count
	if !`r(N)' {
		file open done using "`projDir'/logs/scratch/garbageIcd`2'Sex`3'GC`1'Finished.txt", write replace text
		file write done "done." _n
		file close done
	}

// mark which causes are garbage
	generate garbage = (underlying == "`1'")

// change state and place of death to numeric
	encode placedeath, generate(place)
	encode stateFips, generate(state)

// create factor variables
	xi i.age, prefix(iA)
	xi i.race, prefix(iR)
	xi i.place, prefix(iP)
	xi i.state, prefix(iS)

// loop through each target cause of death
	foreach t of local targets {
	
	// mark each observation for whether it contains that underlying cause
		generate target = (underlying == "`t'")
	
	// run the regression
		capture logit target year iA* iR* iP* iS* A_* B_* C_* G_*, iterate(20)
		if _rc {
			generate estProp`t' = 0
			drop target
			continue
		}
	
	// predict for each of the garbage codes
		predict estProp`t', pr
		drop target
	}

// scale the probabilities so that they sum to 1
	egen totalEstProp = rowtotal(estProp*)
	foreach t of local targets {
		replace estProp`t' = estProp`t' / totalEstProp
	}

// keep just the garbage with its redistribution proportions
	keep if underlying == "`1'"
	keep sex age mcounty year stateFips estProp*

// reshape into number of deaths for each underlying cause
	collapse (sum) estProp*, by(sex age mcounty year stateFips)
	reshape long estProp, i(sex age mcounty year stateFips) j(underlying) string
	rename estProp deaths

// save this redistributed garbage
	save "`projDir'/data/cod/clean/redistributed/redistributed_sex`3'_icd`2'_GC`1'.dta", replace

// save a tmp file so that the main program knows this one has finished
	file open done using "`projDir'/logs/scratch/garbageIcd`2'Sex`3'GC`1'Finished.txt", write replace text
	file write done "done." _n
	file close done

// close the log
	log close
