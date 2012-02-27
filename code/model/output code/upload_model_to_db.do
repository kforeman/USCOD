/*
Author:		Kyle Foreman
Created:	24 Feb 2011
Updated:	27 Feb 2011
Purpose:	upload USCOD model results to the online database
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local proj_dir "D:/projects/`proj'"
	else local proj_dir "/shared/projects/`proj'"

// some information about this model
	// name for model menus
		local name =	"Spatial Intercept"
	// formula (latex, but with *double* escape characters)
		local formula =	"y_{s,c,t} \\sim \\exp(\\alpha + \\gamma \\times t + exposure + \\hat \\beta_{s} + \\beta_{c} + \\beta_{s,c} + d_{s} \\times t + d_{c} \\times t + \\sum_{n=0}^t(u_{s,n}) + \\sum_{n=0}^t(u_{c,n}))"
	// comment (additional model notes; optional)
		local comments = "Spatial smoothing on state intercepts only (not on interactions or slopes). Flexible models on time by cause and state."
	// should the model go at the beginning or the end of the model list? "first" or "last"
		local position = "first"
	// should this model overwrite others with the same name?
		local overwrite = 0
	// location of model results in csv format
		// just one file?
			local multi_file =	1
		// if just one file, put its path here
			local single_file =	"`proj_dir'/outputs/model results/simple loess/simple_loess_in_R.csv"
		// otherwise, first specify the directory
			local file_dir =	"`proj_dir'/outputs/model results/spatial smoothing/"
		// then the file stub (first portion of file name)
			local file_stub =	"spatial_intercept_draws_"
		// finally, the tails to loop through
			local file_tails
			foreach a in "Under5" "5to14" "15to29" "30to44" "45to59" "60to74" "75plus" {
				foreach s in 1 2 {
					local file_tails `file_tails' "`s'_`a'"
				}
			}

// figure out if we already have a working connection to mysql
	capture odbc query sabod

// if unable to connect to mysql, setup an ssh bridge to forward traffic through
	if _rc {
		winexec ssh kjf11@lwf-dev.cc.ic.ac.uk -L 8080:linuxdb-new.cc.ic.ac.uk:3306
		pause on
		display in red "Enter password for MySQL bridge in terminal window, then type 'q' to resume upload"
		pause
	}

// check to see if a model with this name has already been uploaded
	odbc load, exec("SELECT * FROM uscod_models WHERE name='`name'';") dsn(sabod) clear

// if there's already a model by this name
	if _N > 0 {
	// delete it if overwrite is enabled
		if `overwrite' == 1 {
			levelsof model_id, l(id) c
			odbc exec("DELETE FROM uscod_models WHERE name='`name'';"), dsn(sabod)
			odbc exec("DELETE FROM uscod_predictions WHERE model_id=`id';"), dsn(sabod)
		}
	// otherwise throw an error
		else {
			di in red "Model with name '`name'' already exists; set overwrite to 1 and rerun if you wish to continue."
			error
		}
	}

// figure out what the model's sort number should be
	odbc load, exec("SELECT * FROM uscod_models;") dsn(sabod) clear
	summarize sort_order, meanonly
	local sort_order = cond("`position'" == "first", `r(min)'-1, `r(max)'+1)

// load in the data
	if `multi_file' == 0 insheet using "`single_file'", comma clear
	else {
		clear
		foreach t of local file_tails {
			preserve
			insheet using "`file_dir'/`file_stub'`t'.csv", comma clear
			tempfile tf
			save `tf', replace
			restore
			append using `tf'
		}
	}

// get data in the right format
	capture confirm variable mean
	if !_rc local has_mean = "mean"
	else local has_mean = ""
	keep sex year age_group statefips underlying draw* `has_mean'
	rename underlying cause
	rename statefips state
	rename age_group age
	capture confirm string variable state
	if _rc {
		tostring state, replace
		replace state = "0" + state if length(state) == 1
	}

// save the most detailed level
	tempfile level3
	save `level3', replace

// next level
	replace cause = substr(cause, 1, 3)
	collapse (sum) draw* `has_mean', by(year sex cause age state)
	tempfile level2
	save `level2', replace

// and the highest (just A/B/C)
	replace cause = substr(cause, 1, 1)
	collapse (sum) draw* `has_mean', by(year sex cause age state)
	tempfile level1
	save `level1', replace

// finally total deaths
	replace cause = "T"
	collapse (sum) draw* `has_mean', by(year sex cause age state)

// put them back together
	append using `level3'
	append using `level2'
	append using `level1'
	duplicates drop year sex cause age state, force

// add national results
	tempfile state_results
	save `state_results', replace
	collapse (sum) draw* `has_mean', by(year sex cause age)
	generate state = "00"
	append using `state_results'

// add totals across ages
	tempfile age_results
	save `age_results', replace
	collapse (sum) draw* `has_mean', by(year sex cause state)
	generate age = "Total"
	append using `age_results'

// find mean and confidence intervals
	if missing("`has_mean'") egen mean = rowmean(draw*)
	egen lower = rowpctile(draw*), p(2.5)
	egen upper = rowpctile(draw*), p(97.5)
	drop draw*

// make sex, age, and year wide
	generate sex_age_year = "_" + string(sex) + "_" + age + "_" + string(year)
	drop sex age year
	reshape wide mean upper lower, i(state cause) j(sex_age_year) string

// make a new entry for this model in the database
	odbc exec("INSERT INTO uscod_models (name, formula, comments, sort_order) VALUES ('`name'', '`formula'', '`comments'', `sort_order');"), dsn(sabod)

// find the model number of the new entry
	preserve
	odbc load, exec("SELECT * FROM uscod_models WHERE name='`name'';") dsn(sabod) clear
	if _N != 1 {
		di in red "Error - could not create entry for model `name' in MySQL table."
		error
	}
	local id = model_id
	restore

// add model id to all predictions
	generate model_id = `id'

// upload the results
	odbc insert *, table(uscod_predictions) dsn(sabod) insert
