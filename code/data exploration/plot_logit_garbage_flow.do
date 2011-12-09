/*
Author:		Kyle Foreman
Created:	8 December 2011
Updated:	8 December 2011
Purpose:	make a matrix of where the garbage flows to put into a cool d3 visualization
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local proj_dir "D:/projects/`proj'"
	else local proj_dir "/shared/projects/`proj'"

// setup parameters specific to this code
	local icd_list 9 10
	local sex_list 1 2

// find list of causes of death
	use "`proj_dir'/data/cod/clean/COD maps/USCOD_names.dta", clear
	drop if length(uscod) == 1
	levelsof uscod, l(uscods) c
	levelsof uscod if substr(uscod, 1, 1) == "G", l(gcs) c

// load in unredistributed data
	use "`proj_dir'/data/cod/clean/deaths by USCOD/stateDeaths.dta", clear
	keep if inrange(age, 0, 85)
	rename uscod giver
	rename deaths original_deaths

// collapse into national numbers
	collapse (sum) original_deaths, by(sex age year giver)

// square up
	fillin sex giver age year
	replace original_deaths = 0 if _fillin
	drop _fillin

// turn into a matrix with the original values on the diagonal
	foreach c of local uscods {
		generate recipient`c' = cond(substr("`c'", 1, 1) != "G" & giver == "`c'", original_deaths, 0)
	}
	drop original_deaths

// loop through each sex/icd version
	preserve
	foreach v of local icd_list {
		foreach s of local sex_list {
		// loop through each redistribution set
			foreach g of local gcs {
				if ("`g'" == "G_9" & `v' == 9) continue
			
			// load in the redistributed data for this GC
				use "`proj_dir'/data/cod/clean/redistributed/redistributed_sex`s'_icd`v'_GC`g'.dta", clear
				drop if underlying == "T"
			
			// collapse to national
				collapse (sum) deaths, by(sex age year underlying)
			
			// make wide (so that it can be the row of the matrix)
				rename deaths recipient
				reshape wide recipient, i(sex age year) j(underlying) string
			
			// save a temp file
				generate giver = "`g'"
				tempfile rd_`s'_`v'_`g'
				save `rd_`s'_`v'_`g'', replace
			}
		}
	}

// add each garbage code back onto the dataset
	restore
	foreach v of local icd_list {
		foreach s of local sex_list {
			foreach g of local gcs {
				if ("`g'" == "G_10" & `v' == 9) continue
				merge 1:1 sex age year giver using `rd_`s'_`v'_`g'', update replace nogen
			}
		}
	}

// find total for each age/sex/year
	egen given = rowtotal(recipient*)
	bysort age sex year: egen total_asy = sum(given)

// convert to cause fractions
	foreach c of local uscods {
		replace recipient`c' = recipient`c' / total_asy
	}

// outsheet the matrix as csv
	keep sex age year giver recipient*
	outsheet using "`proj_dir'/outputs/data exploration/garbage/garbageFlow.csv", comma replace

	
/*
// find deaths for each cause
	foreach u of local uscods {
		generate package0`u' = cf`u' * deathsTotal
	}
	collapse (sum) package0*, by(year sex age)

// reshape long
	reshape long package0, i(sex age year) j(uscod) string

// save original deaths
	tempfile orig
	save `orig', replace

// loop through each package's redistributions and find the same
	forvalues p = 1 / `numPackages' {
	
	// add in the data (split across for files by icd/sex)
		clear
		foreach v of local icdList {
			foreach s of local sexList {
				append using "`proj_dir'/data/scratch/garbageFlow`p'Sex`s'Icd`v'.dta"
			}
		}
		keep if inrange(age, 0, 85)

	// find numbers of deaths in long format
		forvalues g = 1 / `p' {
			generate cf`gc`g'' = 0
		}
		foreach u of local uscods {
			generate package`p'`u' = cf`u' * deathsTotal
		}
		collapse (sum) package`p'*, by(year sex age)
		reshape long package`p', i(sex age year) j(uscod) string

	// save deaths for this package
		tempfile package`p'
		save `package`p'', replace
	}

// put all the packages together
	use `orig', clear
	forvalues p = 1 / `numPackages' {
		merge 1:1 year sex age uscod using `package`p'', nogen
	}

// switch to cause fractions
	sort sex age year
	forvalues p = 0 / `numPackages' {
		by sex age year: egen package`p'CF = pc(package`p'), prop
	}

// find the increase in cause fraction from one package to the next
	forvalues p = 1 / `numPackages' {
		local q = `p' - 1
		generate rd`p' = package`p'CF - package`q'CF
		replace rd`p' = 0 if rd`p' < 0
	}

// reshape such that we have a matrix of where deaths go (so a row sums to the total in the original dataset, a column sums to the final redistributed total)
	reshape long rd, i(sex age year uscod) j(package)
	generate giver = ""
	forvalues p = 1 / `numPackages' {
		replace giver = "`gc`p''" if package == `p'
	}
	keep sex age year uscod giver rd
	rename rd recipient
	reshape wide recipient, i(sex age year giver) j(uscod) string
	tempfile garbageMatrix
	save `garbageMatrix', replace

// add on rows for the original cause fractions
	use "`proj_dir'/data/cod/clean/deaths by USCOD/stateDeaths.dta", clear
	keep if inrange(age, 0, 85)
	collapse (sum) deaths, by(sex age year uscod)
	bysort sex age year: egen cf = pc(deaths), prop
	drop if substr(uscod, 1, 1) == "G"
	rename uscod giver
	foreach u of local uscods {
		generate recipient`u' = 0
		replace recipient`u' = cf if giver == "`u'"
	}
	drop deaths cf
	append using `garbageMatrix'

// output the matrix for use by d3
	outsheet using "`proj_dir'/outputs/data exploration/garbage/garbageFlow.csv", comma replace
*/
