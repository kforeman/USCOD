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

// begin a matrix to store the number of diabetes deaths
	mata year = J(0, 1, .)
	mata underlying = J(0, 1, .)
	mata anywhere = J(0, 1, .)

// loop through the years
	forvalues y = `startYear' / `endYear' {
		mata year = year \ `y'

	// load in the raw MCD file
		display in red _n "Loading `y'..." _n
		use "`projDir'/data/cod/raw/MCD micro/mcd`y'.dta", clear

	// 	determine if diabetes is listed as the underlying cause
		generate underlying1 = inlist(icd9, "250", "2500", "25000", "25001", "25002", "25003", "25009", "2501", "25010")
		generate underlying2 = inlist(icd9, "25011", "25012", "25013", "25019", "2502", "25020", "25021", "25022", "25023")
		generate underlying3 = inlist(icd9, "25029", "2503", "25030", "25031", "25032", "25033", "25039", "2504", "25040")
		generate underlying4 = inlist(icd9, "25041", "25042", "25043", "25049", "2505", "25050", "25051", "25052", "25053")
		generate underlying5 = inlist(icd9, "25059", "2506", "25060", "25061", "25062", "25063", "25069", "2507", "25070")
		generate underlying6 = inlist(icd9, "25071", "25072", "25073", "25079", "2508", "25080", "25081", "25082", "25083")
		generate underlying7 = inlist(icd9, "25089", "2509", "25090", "25091", "25092", "25093", "25099")
		egen underlying = anymatch(underlying*), v(1)
	
	// mark whether diabetes is present on each line of the death certificate
		quietly describe cause_ent*, varlist
		foreach v in `r(varlist)' {
			generate anywhere1_`v' = inlist(`v', "250", "2500", "25000", "25001", "25002", "25003", "25009", "2501", "25010")
			generate anywhere2_`v' = inlist(`v', "25011", "25012", "25013", "25019", "2502", "25020", "25021", "25022", "25023")
			generate anywhere3_`v' = inlist(`v', "25029", "2503", "25030", "25031", "25032", "25033", "25039", "2504", "25040")
			generate anywhere4_`v' = inlist(`v', "25041", "25042", "25043", "25049", "2505", "25050", "25051", "25052", "25053")
			generate anywhere5_`v' = inlist(`v', "25059", "2506", "25060", "25061", "25062", "25063", "25069", "2507", "25070")
			generate anywhere6_`v' = inlist(`v', "25071", "25072", "25073", "25079", "2508", "25080", "25081", "25082", "25083")
			generate anywhere7_`v' = inlist(`v', "25089", "2509", "25090", "25091", "25092", "25093", "25099")
		}
	
	// check if diabetes was listed on any line
		egen anywhere = anymatch(anywhere*), v(1)
	
	// store the number of diabetes underlying and anywhere deaths
		count if underlying
		mata underlying = underlying \ `r(N)'
		count if anywhere
		mata anywhere = anywhere \ `r(N)'
	}

// save the counts into stata
	clear
	mata:
	st_addobs(rows(year))
	st_store(., st_addvar("int", "year"), year)
	st_store(., st_addvar("float", "underlying"), underlying)
	st_store(., st_addvar("float", "anywhere"), anywhere)
	end

// plot the ratio
	set scheme tufte
	generate ratio = underlying / anywhere
	scatter ratio year, name(ratio, replace) ytitle("Ratio of Underlying to Anywhere") xline(1988.5)
	scatter underlying year, yaxis(1) || scatter anywhere year, yaxis(2) name(levels, replace) legend(ring(0) position(5)) ytitle("Diabetes Underlying", axis(1)) ytitle("Diabetes Anywhere", axis(2)) xline(1988.5)
	graph combine ratio levels, rows(2)
	graph export "`projDir'/outputs/data exploration/diabetesIcd9.pdf", replace
	