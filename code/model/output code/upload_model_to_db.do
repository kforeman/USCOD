/*
Author:		Kyle Foreman
Created:	24 Feb 2011
Updated:	24 Feb 2011
Purpose:	upload USCOD model results to the online database
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local proj_dir "D:/projects/`proj'"
	else local proj_dir "/shared/projects/`proj'"

// some information about this model
	// location of model results in csv format
		local file =	"`proj_dir'/outputs/model results/simple loess/simple_loess_in_R.csv"
	// name for model menus
		local name =	"Simple LOESS"
	// formula (latex, but with *double* escape characters)
		local formula =	"\\ln(rate_{state, age, sex, cause, year}) = \\mathrm{LOESS}(\\ln(rate_{state, age, sex, cause}))"
	// comment (additional model notes; optional)
		local comment = ""
	// should this model overwrite others with the same name?
		local overwrite = 0

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

// load in the data
	insheet using "`file'", comma case clear

// get data in the right format
	keep sex year age_group stateFips underlying draw*
	rename underlying cause
	rename stateFips state
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
	collapse (sum) draw*, by(year sex cause age state)
	tempfile level2
	save `level2', replace

// and the highest (just A/B/C)
	replace cause = substr(cause, 1, 1)
	collapse (sum) draw*, by(year sex cause age state)
	tempfile level1
	save `level1', replace

// finally total deaths
	replace cause = "T"
	collapse (sum) draw*, by(year sex cause age state)

// put them back together
	append using `level3'
	append using `level2'
	append using `level1'
	duplicates drop year sex cause age state, force

// add national results
	tempfile state_results
	save `state_results', replace
	collapse (sum) draw*, by(year sex cause age)
	generate state = "00"
	append using `state_results'

// add totals across ages
	tempfile age_results
	save `age_results', replace
	collapse (sum) draw*, by(year sex cause state)
	generate age = "Total"
	append using `age_results'

// find mean and confidence intervals
	egen mean = rowmean(draw*)
	egen lower = rowpctile(draw*), p(2.5)
	egen upper = rowpctile(draw*), p(97.5)
	drop draw*

// make sex, age, and year wide
	generate sex_age_year = "_" + string(sex) + "_" + age + "_" + string(year)
	drop sex age year
	reshape wide mean upper lower, i(state cause) j(sex_age_year) string

// make a new entry for this model in the database
	odbc exec("INSERT INTO uscod_models (name, formula, comments) VALUES ('`name'', '`formula'', '`comments'');"), dsn(sabod)

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
