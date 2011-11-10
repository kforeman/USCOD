/*
Author:		Kyle Foreman
Created:	10 Nov 2011
Updated:	10 Nov 2011
Purpose:	build a dataset appropriate for testing Gretchen and Gary's matching approach for garbage redistribution
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup parameters specific to this code
	local startYear = 		1979
	local endYear = 		2007
	local icdSwitchYear = 	1999

// in order to use Sandeep's code for fixing FIPS codes, need to specify where all his stuff is located
	global merge "`projDir'/data/geo/raw/sandeeps merge maps/"

// load in list of USCOD codes
	use "`projDir'/data/cod/clean/COD maps/USCOD_names.dta", clear
	** drop if inlist(uscod, "A", "B", "B_1", "B_3", "C", "C_1", "C_2", "G")
	levelsof uscod, l(uscods) c
	** foreach c of local uscods {
		** levelsof uscodName if uscod == "`c'", l(`c'_name) c
	** }

// loop through the years
	forvalues y = `startYear' / `endYear' {

	// load in the raw MCD file
		display in red _n "Loading `y'..." _n
		use "`projDir'/data/cod/raw/MCD micro/mcd`y'.dta", clear

	// map underlying cause to USCOD
		if inrange( `y', `startYear', `icdSwitchYear'-1) {
			rename icd9 cause
			merge m:1 cause using "`projDir'/data/cod/clean/COD maps/ICD9_to_USCOD.dta", nogen keep(match)
		}
		else if inrange( `y', `icdSwitchYear', 2001) {
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
			if `y' < `icdSwitchYear' quietly merge m:1 cause using "`projDir'/data/cod/clean/COD maps/ICD9_to_USCOD.dta", nogen keep(match master)
			else quietly merge m:1 cause using "`projDir'/data/cod/clean/COD maps/ICD10_to_USCOD.dta", nogen keep(match master)
			rename uscod cause`i'
			drop cause
		}

	// convert age to the correct format
		quietly {
			generate age = .
			replace age = 0 if inlist(substr(age_detail,1,1), "2", "3", "4", "5", "6")
			if `y' >= 2003 {
				replace age = floor(real(substr(age_detail,2,3))/5)*5 if substr(age_detail,1,1) == "1"
				replace age = 85 if (age > 85 & age != .)
			}
			else { 
				replace age = floor(real(substr(age_detail,2,2))/5)*5 if substr(age_detail,1,1) == "0"
				replace age = 85 if substr(age_detail,1,1) == "1" | (age > 85 & age != .)
			}
		}
	
	// group into race categories
		quietly do "`projDir'/code/data prep/MCD/fixRace.do" `y'
	
	// use Sandeep's code to convert to appropriate FIPS codes
		quietly do "`projDir'/code/data prep/geo/sandeepsFipsFixer.do" `y'
	
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
		generate year = `y'
		generate stateFips = substr(string(mcounty),1,2)
		replace stateFips = "0" + substr(string(mcounty),1,1) if length(string(mcounty)) == 4
	
	// save a tempfile
		tempfile tmp`y'
		save `tmp`y'', replace
	}

// compile results
	clear
	forvalues y = `startYear' / `endYear' {
		append using `tmp`y''
	}

// I guess save the outputs or something
	save "`projDir'/data/clean/garbage inputs/matchingTestDataset.dta", replace
