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

// where to store the outputs?
	if c(os) == "Windows" local out_dir "D:/Dropbox/model_explorer/data/"
	else local out_dir "/shared/Dropbox/model_explorer/data/"

// figure out if we already have a working connection to mysql
	capture odbc query sabod

// if unable to connect to mysql, setup an ssh bridge to forward traffic through
	if _rc {
		winexec ssh kjf11@lwf-dev.cc.ic.ac.uk -L 8080:linuxdb-new.cc.ic.ac.uk:3306
		pause on
		display in red "Enter password for MySQL bridge in terminal window, then type 'q' to resume upload"
		pause
	}

// download cause names
	odbc load, exec("SELECT * FROM uscod_causes ORDER BY sort_order;") dsn(sabod) clear
	sort sort_order
	levelsof cause, l(causes) c
	outsheet using "`out_dir'/parameters/causes.csv", comma replace

// download state names
	odbc load, exec("SELECT * FROM uscod_states ORDER BY sort_order;") dsn(sabod) clear
	drop sort_order
	levelsof state, l(states) c
	outsheet using "`out_dir'/parameters/states.csv", comma replace

// download list of models
	odbc load, exec("SELECT * FROM uscod_models ORDER BY model_id;") dsn(sabod) clear
	levelsof model_id, l(model_ids) c
	foreach m of local model_ids {
		capture mkdir "`out_dir'/predictions/by cause/`m'/"
		capture mkdir "`out_dir'/predictions/by state/`m'/"
	}
	outsheet using "`out_dir'/parameters/models.csv", comma replace

// download years
	odbc load, exec("SELECT * FROM uscod_years ORDER BY year;") dsn(sabod) clear
	outsheet using "`out_dir'/parameters/years.csv", comma replace

// download ages
	odbc load, exec("SELECT * FROM uscod_ages ORDER BY sort_order;") dsn(sabod) clear
	outsheet using "`out_dir'/parameters/ages.csv", comma replace

// download deaths, save separately by cause and by state
	odbc load, exec("SELECT * FROM uscod_deaths;") dsn(sabod) clear
	preserve
	foreach c of local causes {
		keep if cause == "`c'"
		outsheet using "`out_dir'/deaths/by cause/deaths_`c'.csv", comma replace
		restore, preserve
	}
	foreach s of local states {
		keep if state == "`s'"
		outsheet using "`out_dir'/deaths/by state/deaths_`s'.csv", comma replace
		restore, preserve
	}
	restore, not

// download population, saving by state
	odbc load, exec("SELECT * FROM uscod_pop;") dsn(sabod) clear
	outsheet using "`out_dir'/pop/pop.csv", comma replace

// download model results, save separately by cause and by state
	odbc load, exec("SELECT * FROM uscod_predictions;") dsn(sabod) clear
	preserve
	foreach c of local causes {
		foreach m of local model_ids {
			keep if cause == "`c'" & model_id == `m'
			outsheet using "`out_dir'/predictions/by cause/`m'/pred_`c'.csv", comma replace
			restore, preserve
		}
	}
	foreach s of local states {
		foreach m of local model_ids {
			keep if state == "`s'" & model_id == `m'
			outsheet using "`out_dir'/predictions/by state/`m'/pred_`s'.csv", comma replace
			restore, preserve
		}
	}
	restore, not
