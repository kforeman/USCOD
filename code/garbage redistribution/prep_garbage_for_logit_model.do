/*
Author:		Kyle Foreman
Created:	10 November 2011
Updated:	9 December 2011
Purpose:	build a dataset appropriate for testing Gretchen and Gary's matching approach for garbage redistribution
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// start logging
	log using "`projDir'/logs/scratch/multicause`1'.smcl", replace

// in order to use Sandeep's code for fixing FIPS codes, need to specify where all his stuff is located
	global merge "`projDir'/data/geo/raw/sandeeps merge maps/"
	local icdSwitchYear 1999

// load in list of USCOD codes
	use "`projDir'/data/cod/clean/COD maps/USCOD_names.dta", clear
	drop if inlist(uscod, "A", "B", "B_1", "B_3", "C", "C_1", "C_2", "G")
	levelsof uscod, l(uscods) c

// load in the raw MCD file
	display in red _n "Loading `1'..." _n
	use "`projDir'/data/cod/raw/MCD micro/mcd`1'.dta", clear

// map underlying cause to USCOD
	if `1' < `icdSwitchYear' {
		rename icd9 cause
		merge m:1 cause using "`projDir'/data/cod/clean/COD maps/ICD9_to_USCOD.dta", nogen keep(match)
	}
	else if inrange( `1', `icdSwitchYear', 2001) {
		rename icd10 cause
		merge m:1 cause using "`projDir'/data/cod/clean/COD maps/ICD10_to_USCOD.dta", nogen keep(match)
	}
	else {
		merge m:1 cause using "`projDir'/data/cod/clean/COD maps/ICD10_to_USCOD.dta", nogen keep(match)
	}
	rename uscod underlying
	drop cause
	
// get rid of causes on line 6
	forvalues i = 1 / 20 {
		quietly replace cause_ent`i' = "" if substr(seqn_ent`i', 1, 1) == "6"
	}

// for each cause, map to the USCOD cause
	forvalues i = 1 / 20 {
		rename cause_ent`i' cause
		if `1' < `icdSwitchYear' quietly merge m:1 cause using "`projDir'/data/cod/clean/COD maps/ICD9_to_USCOD.dta", nogen keep(match master)
		else quietly merge m:1 cause using "`projDir'/data/cod/clean/COD maps/ICD10_to_USCOD.dta", nogen keep(match master)
		rename uscod cause`i'
		drop cause
	}

// convert age to the correct format
	quietly {
		generate age = .
		replace age = 0 if inlist(substr(age_detail,1,1), "2", "3", "4", "5", "6")
		if `1' >= 2003 {
			replace age = floor(real(substr(age_detail,2,3))/5)*5 if substr(age_detail,1,1) == "1"
			replace age = 85 if (age > 85 & age != .)
		}
		else { 
			replace age = floor(real(substr(age_detail,2,2))/5)*5 if substr(age_detail,1,1) == "0"
			replace age = 85 if substr(age_detail,1,1) == "1" | (age > 85 & age != .)
		}
	}

// group into race categories
	quietly do "`projDir'/code/data prep/MCD/fixRace.do" `1'

// use Sandeep's code to convert to appropriate FIPS codes
	quietly do "`projDir'/code/data prep/geo/sandeepsFipsFixer.do" `1'
	replace mcounty = real(fip) if mcounty == .

// make sure sex is in the right format
	capture confirm numeric variable sex
	quietly {
		if _rc {
			rename sex sexStr
			generate sex = .
			replace sex = 1 if sexStr == "M"
			replace sex = 2 if sexStr == "F"
			drop sexStr
		}
		else replace sex = . if !inlist( sex, 1, 2 )
	}

// keep just the relevant variables
	keep mcounty sex age race placedeath underlying cause1-cause20

// for every cause, figure out which rows contain it
	foreach c of local uscods {
		forvalues i = 1 / 20 {
			generate match`i' = (cause`i' == "`c'")
		}
		egen `c' = anymatch(match1-match20), v(1)
		label variable `c' "``c'_name'"
		drop match1-match20
	}

// add a couple more variables
	drop cause*
	generate year = `1'
	generate stateFips = substr(string(mcounty),1,2)
	replace stateFips = "0" + substr(string(mcounty),1,1) if length(string(mcounty)) == 4

// save the results
	save "`projDir'/data/scratch/multicause`1'.dta", replace

// save a tmp file so that the main program knows this one has finished
	file open done using "`projDir'/logs/scratch/multicause`1'.txt", write replace text
	file write done "done." _n
	file close done
	log close
