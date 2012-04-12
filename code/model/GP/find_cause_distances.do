/*
Author:		Kyle Foreman
Created:	04 Apr 2011
Updated:	04 Apr 2011
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

// reshape by cause
	reshape wide ln_rate_, i(sex year stateFips age_group) j(underlying) string

// label with names
	preserve
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

// run PCA
	pca A_* B_* C_* if sex==2 & age_group=="75plus", components(2)
	rotate, varimax
	loadingplot
	
	