/*
Author:		Kyle Foreman
Created:	04 Apr 2011
Updated:	12 Apr 2011
Purpose:	use PCA to find Euclidean distances between causes
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local proj_dir "D:/projects/`proj'"
	else local proj_dir "/shared/projects/`proj'"

// load in the data
	use "`proj_dir'/data/model inputs/state_random_effects_input.dta", clear

// create log rates
	generate ln_rate_ = ln(deaths / pop * 100000)
	drop deaths pop

// replace zeros with smallest observed value
	summarize ln_rate_, meanonly
	replace ln_rate_ = `r(min)' if ln_rate_ == .

// find list of causes
	levelsof underlying, l(causes) c

// reshape by cause
	reshape wide ln_rate_, i(sex year stateFips age_group) j(underlying) string

// label with names
/*	preserve
	use "`proj_dir'/data/cod/clean/COD maps/uscod_names.dta", clear
	levelsof uscod, l(uscods) c
	foreach c of local uscods {
		levelsof short_name if uscod == "`c'", l(`c'_name) c
	}
	restore
	foreach c of local uscods {
		capture confirm variable ln_rate_`c'
		if !_rc rename ln_rate_`c' `c'_``c'_name'
	}
*/

// rename variables to only include cause
	foreach c of local causes {
		rename ln_rate_`c' `c'
	}

// load in matrix to csv program
	do "`proj_dir'/code/model/GP/mat2csv.ado"

// run PCA
	levelsof age_group, l(ages) c
	foreach s in 1 2 {
		foreach a of local ages {
			pca A_* B_* C_* if sex == `s' & age_group == "`a'", components(3)
			rotate, varimax
			matrix tmp = e(r_L)
			mat2csv, matrix(tmp) saving("`proj_dir'/outputs/model results/cause distances/distances_`s'_`a'.csv") replace note("") subnote("")
		}
	}
	// loadingplot
