/*
Author:		Kyle Foreman
Created:	10 Nov 2011
Updated:	10 Nov 2011
Purpose:	build a dataset appropriate for testing Gretchen and Gary's matching approach for garbage redistribution
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup parameters specific to this code
	local startYear = 		1979
	local endYear = 		2007

// change to the scratch log directory so that outputs will be stored there
	cd "`projDir'/logs/scratch/"

// loop through the years
	forvalues y = `startYear' / `endYear' {
	
	// make a directory to store scratch files for the currently running file (stupid stata won't let you override where it saves its awful default logs, meaning if you run the same program with different arguments it gets disk read slowness...)
		capture mkdir "multicause`y'"
		cd "multicause`y'"

	// delete the temporary file signifying this program has completed in case it still exists from a previous attempt
		capture rm "multicause`y'.txt"
		
	// start running the program
		winexec "C:/Program Files (x86)/Stata12/StataMP-64.exe" /e do \"`projDir'/code/garbage redistribution/prep_garbage_for_logit_model.do\" `y'
		
	// switch back to the main scratch directory
		cd ..
	
	// pause 5 minutes between each batch of 5 submitted
		if mod(`y', 5) == 0 sleep 300000
	}

// loop through the years and don't proceed until each is done running
	forvalues y = `startYear' / `endYear' {
		local done = 0
		while `done' == 0 {
			capture confirm file "multicause`y'.txt"
			if _rc == 0 local done = 1
			else {
				sleep 45000
				display in yellow "." _c
			}
		}
	}

// now that everything has finished running, put the pieces back together
	clear
	forvalues y = `startYear' / `endYear' {
		append using "`projDir'/data/scratch/multicause`y'.dta"
	}

// save the final file
	compress
	save "`projDir'/data/cod/clean/garbage inputs/matchingTestDataset.dta", replace

// delete temporary files
	forvalues y = `startYear' / `endYear' {
		capture rm "`projDir'/data/scratch/multicause`y'.dta"
		capture rm "`projDir'/logs/scratch/multicause`y'.txt"
		capture rm "`projDir'/logs/scratch/multicause`y'.smcl"
		capture !erase "`projDir'/logs/scratch/multicause`y'" /s /q
	}

// run redistribution
	do "`projDir'/code/garbage redistribution/runRedistributionTest.do"
