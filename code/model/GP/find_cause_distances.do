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

// how many dimensions (components) to include in the PCA?
	local num_dim = 3

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
			pca A_* B_* C_* if sex == `s' & age_group == "`a'", components(`num_dim')
			rotate, varimax
			matrix tmp = e(r_L)
			mat2csv, matrix(tmp) saving("`proj_dir'/outputs/model results/cause distances/distances_`s'_`a'.csv") replace note("") subnote("")
		}
	}

// load in cause names
	use "`proj_dir'/data/cod/clean/COD maps/uscod_names.dta", clear
	foreach c of local causes {
		levelsof short_name if uscod == "`c'", l(`c'_name) c
	}

// compute distance matrices
	foreach s in 1 2 {
		foreach a of local ages {
			insheet using "`proj_dir'/outputs/model results/cause distances/distances_`s'_`a'.csv", comma clear
			levelsof row, l(rows) c
			foreach c of local rows {
				generate `c'_``c'_name' = 0
				forvalues i = 1/`num_dim' {
					summarize comp`i' if row == "`c'", meanonly
					replace `c'_``c'_name' = `c'_``c'_name' + (comp`i' - `r(mean)')^2
				}
				replace `c'_``c'_name' = sqrt(`c'_``c'_name')
				replace `c'_``c'_name' = 0 if row == "`c'"
				replace row = "`c'_``c'_name'" if row == "`c'"
			}
			drop comp*
			rename row cause
			outsheet using "`proj_dir'/outputs/model results/cause distances/dist_mat_`s'_`a'.csv", comma replace
		}
	}
