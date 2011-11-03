/*
Author:		Kyle Foreman
Created:	31 October 2011
Updated:	31 October 2011
Purpose:	make a matrix of where the garbage flows to put into a cool d3 visualization
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup parameters specific to this code
	local icdList 9 10
	local sexList 1 2

// load in the list of garbage packages
	import excel using "`projDir'/data/cod/raw/GC/garbageRedistribution.xlsx", clear sheet("Garbage") firstrow
	describe A_* B_* C_*, varlist
	local uscods `r(varlist)'
	sort Order
	local numPackages = _N
	forvalues p = 1 / `numPackages' {
		local gc`p' = GC[`p']
		local name`p' = Description[`p']
		local uscods `uscods' `gc`p''
	}

// load in unredistributed cause of death data by county
	use "`projDir'/data/cod/clean/deaths by USCOD/countyCFs.dta", clear
	keep if inrange(age, 0, 85)

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
				append using "`projDir'/data/scratch/garbageFlow`p'Sex`s'Icd`v'.dta"
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
	use "`projDir'/data/cod/clean/deaths by USCOD/stateDeaths.dta", clear
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
	outsheet using "`projDir'/outputs/data exploration/garbage/garbageFlow.csv", comma replace
