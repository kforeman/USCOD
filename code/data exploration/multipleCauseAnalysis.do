/*
Author:		Kyle Foreman
Created:	8 Nov 2011
Updated:	8 Nov 2011
Purpose:	look at which causes co-occur with diabetes/renal failure/septicaemia
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup parameters specific to this code
	local startYear = 		1979
	local endYear = 		2007
	local icdSwitchYear = 	1999

// load in list of USCOD codes
	use "`projDir'/data/cod/clean/COD maps/USCOD_names.dta", clear
	drop if inlist(uscod, "A", "B", "B_1", "B_3", "C", "C_1", "C_2", "G")
	levelsof uscod, l(uscods) c
	foreach c of local uscods {
		levelsof uscodName if uscod == "`c'", l(`c'_name) c
	}

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
	
	// keep just the relevant variables
		keep underlying cause1-cause20
	
	// for every cause, figure out which rows contain it
		foreach c of local uscods {
			forvalues i = 1 / 20 {
				generate match`i' = (cause`i' == "`c'")
			}
			egen `c' = anymatch(match1-match20), v(1)
			label variable `c' "``c'_name'"
			drop match1-match20
		}

	// count the pairwise matches between each underlying cause and everything else on the death certificate
		drop cause*
		collapse (mean) A_* B_* C_* G_*, by(underlying) fast

	// save a temp file for later aggregation (to plot trends and such)
		generate year = `y'
		tempfile tab`y'
		save `tab`y'', replace
	
	// save a heatmap
		foreach c of local uscods {
			label variable `c' "``c'_name'"
		}
		drop year
		rename underlying uscod
		merge 1:1 uscod using "`projDir'/data/cod/clean/COD maps/USCOD_names.dta", keep(match) nogen
		order uscod uscodName
		label variable uscod "Underlying Cause"
		label variable uscodName "Name"
		if `y' == `startYear' export excel using "`projDir'/outputs/data exploration/multi cause/multiCausePairings.xlsx", sheetmodify sheet("`y'") firstrow(varlabels)
		else export excel using "`projDir'/outputs/data exploration/multi cause/multiCausePairings.xlsx", sheetmodify sheet("`y'") firstrow(varlabels)
	}

// compile results
	clear
	forvalues y = `startYear' / `endYear' {
		append using `tab`y''
	}

// reshape such that we have the proportion for each related cause long
	rename A_* proportionA_*
	rename B_* proportionB_*
	rename C_* proportionC_*
	rename G_* proportionG_*
	reshape long proportion, i(underlying year) j(uscod) string
	merge m:1 uscod using "`projDir'/data/cod/clean/COD maps/USCOD_names.dta", keep(match) nogen
	generate related = subinstr(uscod, "_", ".", .) + " " + uscodName

// for each underlying cause, plot the related causes over time
	set scheme tufte
	capture mkdir "`projDir'/outputs/data exploration/multi cause/pdftemp"
	preserve
	foreach c of local uscods {
		keep if underlying == "`c'"
		scatter proportion year, by(related, yrescale title("``c'_name' as Underlying")) xline(1998.5, lcolor(black)) xline(1988.5, lcolor(gray)) ytitle("Proportion of Cases Listing Additional Cause") xlabel(,labsize(small))
		graph export "`projDir'/outputs/data exploration/multi cause/pdftemp/`c'.pdf", replace
		restore, preserve
	}
	!"C:/ado/pdftk/pdftk.exe" "`projDir'/outputs/data exploration/multi cause/pdftemp/*.pdf" cat output "`projDir'/outputs/data exploration/multi cause/multipleCauses.pdf"
