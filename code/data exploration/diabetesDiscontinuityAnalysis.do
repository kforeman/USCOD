/*
Author:		Kyle Foreman
Created:	4 Nov 2011
Updated:	4 Nov 2011
Purpose:	check all the ICD9 years for both diabetes as underlying cause and diabetes mentioned anywhere, plot them against each other
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup parameters specific to this code
	local startYear = 		1979
	local endYear = 		1998

// loop through the years
	forvalues y = `startYear' / `endYear' {
		mata year = year \ `y'

	// load in the raw MCD file
		display in red _n "Loading `y'..." _n
		use "`projDir'/data/cod/raw/MCD micro/mcd`y'.dta", clear
	
	// reshape so that there's one observation for each cause listed on the death certificate
		generate cause_ent0 = icd9
		generate seqn_ent0 = "00"
		generate id = _n
		keep id cause_ent* seqn_ent*
		reshape long cause_ent seqn_ent, i(id) j(position)
		drop if cause_ent == ""

	// 	determine if diabetes is listed as the cause
		generate diabetes1 = inlist(cause_ent, "250", "2500", "25000", "25001", "25002", "25003", "25009", "2501", "25010")
		generate diabetes2 = inlist(cause_ent, "25011", "25012", "25013", "25019", "2502", "25020", "25021", "25022", "25023")
		generate diabetes3 = inlist(cause_ent, "25029", "2503", "25030", "25031", "25032", "25033", "25039", "2504", "25040")
		generate diabetes4 = inlist(cause_ent, "25041", "25042", "25043", "25049", "2505", "25050", "25051", "25052", "25053")
		generate diabetes5 = inlist(cause_ent, "25059", "2506", "25060", "25061", "25062", "25063", "25069", "2507", "25070")
		generate diabetes6 = inlist(cause_ent, "25071", "25072", "25073", "25079", "2508", "25080", "25081", "25082", "25083")
		generate diabetes7 = inlist(cause_ent, "25089", "2509", "25090", "25091", "25092", "25093", "25099")
		egen diabetes = anymatch(diabetes*), v(1)

	// parse out line of death certificate
		generate line = real(substr(seqn_ent, 1, 1))
	
	// for each death, find whether underlying and each line had diabetes
		collapse (max) diabetes, by(id line)

	// count how many times diabetes occurs in each case
		collapse (sum) diabetes, by(line)
	
	// save a temp file
		generate year = `y'
		tempfile diab`y'
		save `diab`y'', replace
	}

// compile results
	clear
	forvalues y = `startYear' / `endYear' {
		append using `diab`y''
	}

// save the results
	outsheet using "`projDir'/outputs/data exploration/diabetes/diabetesByLine.csv", comma replace

// plot the ratio
	set scheme tufte
	/* generate ratio = underlying / anywhere
	scatter ratio year, name(ratio, replace) ytitle("Ratio of Underlying to Anywhere") xline(1988.5)
	scatter underlying year, yaxis(1) || scatter anywhere year, yaxis(2) name(levels, replace) legend(ring(0) position(5)) ytitle("Diabetes Underlying", axis(1)) ytitle("Diabetes Anywhere", axis(2)) xline(1988.5)
	graph combine ratio levels, rows(2)
	graph export "`projDir'/outputs/data exploration/diabetes/diabetesIcd9.pdf", replace */
	