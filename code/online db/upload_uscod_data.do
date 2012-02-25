/*
Author:		Kyle Foreman
Created:	27 Jan 2011
Updated:	27 Jan 2011
Purpose:	upload the cause of death and population/envelope data by state to the online database
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local proj_dir "D:/projects/`proj'"
	else local proj_dir "/shared/projects/`proj'"

// which tables to update?
	local update_causes =	1
	local update_years = 	1
	local update_ages =		1
	local update_states =	1
	local update_deaths =	1
	local update_pop =		1
	local recreate_model_tables =	1

// figure out if we already have a working connection to mysql
	capture odbc query sabod

// if unable to connect to mysql, setup an ssh bridge to forward traffic through
	if _rc {
		winexec ssh kjf11@lwf-dev.cc.ic.ac.uk -L 8080:linuxdb-new.cc.ic.ac.uk:3306
		pause on
		display in red "Enter password for MySQL bridge in terminal window, then type 'q' to resume upload"
		pause
	}

	if (`update_causes') {
	// find cause names
		insheet using "`proj_dir'/data/cod/clean/COD maps/uscod_for_menus.csv", comma clear
		rename uscod cause
		rename uscodname name
		rename short_sweet short
		drop menu_name
		drop short_name
		rename order sort_order
		compress
		tempfile cause_names
		save `cause_names', replace

	// upload cause names
		odbc exec("DROP TABLE IF EXISTS uscod_causes;"), dsn(sabod)
		odbc insert *, table(uscod_causes) create dsn(sabod) sqlshow
	}

	if (`update_states') {
	// find state names
		insheet using "`proj_dir'/data/geo/clean/state_names.csv", comma clear
		tostring statefips, generate(state)
		replace state = "0" + state if statefips < 10
		drop statefips
		capture drop v*
		local nn = _N + 1
		sort name
		set obs `nn'
		replace name = "National" in `nn'
		replace state = "00" in `nn'
		replace abbrev = "US" in `nn'
		generate sort_order = _n
		replace sort_order = 0 in `nn'
		sort sort_order

	// upload state names
		odbc exec("DROP TABLE IF EXISTS uscod_states;"), dsn(sabod)
		odbc insert *, table(uscod_states) create dsn(sabod) sqlshow
	}

// load in the dataset used for modeling
	use "`proj_dir'/data/model inputs/state_random_effects_input.dta", clear
	summarize year, meanonly
	local min_year = `r(min)'
	local max_year = `r(max)'
	
	if (`update_years') {
	// find which years are used
		preserve
		keep year
		duplicates drop
		sort year
	
	// upload years to the server
		odbc exec("DROP TABLE IF EXISTS uscod_years;"), dsn(sabod)
		odbc insert *, table(uscod_years) create dsn(sabod) sqlshow
		restore
	}
	
	if (`update_ages') {
	// find age groups
		preserve
		keep age_group
		duplicates drop
		rename age_group age
		generate sort_order = .
		generate name = ""
		replace sort_order = 1 		if age == "Under5"
		replace name = "Under 5"	if age == "Under5"
		replace sort_order = 2 		if age == "5to14"
		replace name = "4 to 15"	if age == "5to14"
		replace sort_order = 3 		if age == "15to29"
		replace name = "15 to 29"	if age == "15to29"
		replace sort_order = 4 		if age == "30to44"
		replace name = "30 to 44"	if age == "30to44"
		replace sort_order = 5 		if age == "45to59"
		replace name = "45 to 59"	if age == "45to59"
		replace sort_order = 6 		if age == "60to74"
		replace name = "60 to 74"	if age == "60to74"
		replace sort_order = 7 		if age == "75plus"
		replace name = "75 plus" 	if age == "75plus"
		sort sort_order
		set obs 8
		replace sort_order = 8 in 8
		replace age = "Total" in 8
		replace name = "Total" in 8
	
	// upload ages
		odbc exec("DROP TABLE IF EXISTS uscod_ages;"), dsn(sabod)
		odbc insert *, table(uscod_ages) create dsn(sabod) sqlshow
		levelsof age, local(ages) c
		restore
	}

	if (`update_deaths' == 1) {
	// get data in the right format
		preserve
		keep sex year age_group stateFips deaths underlying
		rename underlying cause
		rename stateFips state
		rename age_group age
	
	// save the most detailed level
		tempfile level3
		save `level3', replace
	
	// next level
		replace cause = substr(cause, 1, 3)
		collapse (sum) deaths, by(year sex cause age state)
		tempfile level2
		save `level2', replace
	
	// and the highest (just A/B/C)
		replace cause = substr(cause, 1, 1)
		collapse (sum) deaths, by(year sex cause age state)
		tempfile level1
		save `level1', replace
	
	// finally total deaths
		replace cause = "T"
		collapse (sum) deaths, by(year sex cause age state)
		replace deaths = round(deaths)
	
	// put them back together
		append using `level3'
		append using `level2'
		append using `level1'
		duplicates drop
	
	// make sex, age, and year wide
		generate sex_age_year = "_" + string(sex) + "_" + age + "_" + string(year)
		drop sex age year
		reshape wide deaths, i(state cause) j(sex_age_year) string
	
	// add national results
		tempfile state_results
		save `state_results', replace
		collapse (sum) deaths_*, by(cause)
		generate state = "00"
		append using `state_results'
	
	// add total across ages
		foreach s in 1 2 {
			forvalues y = `min_year' / `max_year' {
				egen deaths_`s'_Total_`y' = rowtotal(deaths_`s'_*_`y')
			}
		}

	// upload the results
		odbc exec("DROP TABLE IF EXISTS uscod_deaths;"), dsn(sabod)
		odbc insert *, table(uscod_deaths) create dsn(sabod) sqlshow
	
	// add indices
		odbc exec("ALTER TABLE uscod_deaths ADD INDEX (state);"), dsn(sabod)
		odbc exec("ALTER TABLE uscod_deaths ADD INDEX (cause);"), dsn(sabod)
		restore
	}

	if (`update_pop' == 1) {
	// pull out just the populations
		preserve
		keep sex year age_group stateFips pop
		duplicates drop
		rename stateFips state
		rename age_group age
		compress
	
	// make sex, age, and year wide
		generate sex_age_year = "_" + string(sex) + "_" + age + "_" + string(year)
		drop sex age year
		reshape wide pop, i(state) j(sex_age_year) string
	
	// add national results
		tempfile state_results
		save `state_results', replace
		collapse (sum) pop_*
		generate state = "00"
		append using `state_results'
	
	// add total across ages
		foreach s in 1 2 {
			forvalues y = `min_year' / `max_year' {
				egen pop_`s'_Total_`y' = rowtotal(pop_`s'_*_`y')
			}
		}
	
	// upload populations to server
		odbc exec("DROP TABLE IF EXISTS uscod_pop;"), dsn(sabod)
		odbc insert *, table(uscod_pop) create dsn(sabod) sqlshow
	
	// add indices
		odbc exec("ALTER TABLE uscod_pop ADD INDEX (state);"), dsn(sabod)
		restore
	}

// recreate the model tables if specified (Note: you must manually drop them beforehand)
	if (`recreate_model_tables' == 1) {
	
	// create the list of models
		odbc exec("CREATE TABLE IF NOT EXISTS uscod_models (model_id INT AUTO_INCREMENT, name VARCHAR(250), formula TEXT, comments TEXT, date TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (model_id));"), dsn(sabod)
	
	// create the model results table
		odbc exec("CREATE TABLE IF NOT EXISTS uscod_predictions LIKE uscod_deaths;"), dsn(sabod)
		foreach s in 1 2 {
			forvalues y = `min_year' / `max_year' {
				foreach a of local ages {
					quietly {
						odbc exec("ALTER TABLE uscod_predictions DROP COLUMN deaths_`s'_`a'_`y', ADD COLUMN mean_`s'_`a'_`y' FLOAT, ADD COLUMN lower_`s'_`a'_`y' FLOAT, ADD COLUMN upper_`s'_`a'_`y' FLOAT;"), dsn(sabod)
					}
				}
			}
		}
		odbc exec("ALTER TABLE uscod_predictions ADD COLUMN model_id INT FIRST;"), dsn(sabod)
		odbc exec("ALTER TABLE uscod_predictions ADD INDEX (model_id);"), dsn(sabod)
		odbc exec("ALTER TABLE uscod_predictions ADD INDEX (model_id, cause);"), dsn(sabod)
		odbc exec("ALTER TABLE uscod_predictions ADD INDEX (model_id, state);"), dsn(sabod)
	}
