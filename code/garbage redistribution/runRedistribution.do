/*
Author:		Kyle Foreman
Created:	27 October 2011
Updated:	27 October 2011
Purpose:	run the redistribution for both icd versions and sexes in parallel (Windows only for right now...)
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup parameters specific to this code
	local icdList 9 10
	local sexList 1 2

// change to the scratch log directory so that outputs will be stored there
	cd "`projDir'/logs/scratch/"

// loop through the sexes
	foreach s of local sexList {
	
	// loop through icd versions
		foreach v of local icdList {
			
		// make a directory to store scratch files for the currently running file (stupid stata won't let you override where it saves its awful default logs, meaning if you run the same program with different arguments it gets disk read slowness...)
			capture mkdir "icd`v'Sex`s'"
			cd "icd`v'Sex`s'"

		// delete the temporary file signifying this program has completed in case it still exists from a previous attempt
			capture rm "garbageIcd`v'Sex`s'Finished.txt"
		
		// start running the program
			winexec "C:/Program Files (x86)/Stata12/StataMP-64.exe" /e do \"`projDir'/code/garbage redistribution/redistributeGarbage.do\" `s' `v'
		
		// switch back to the main scratch directory
			cd ..		
		}
	}

// loop through each sex/icd version and don't proceed until it's done running
	foreach s of local sexList {
		foreach v of local icdList {
			local done = 0
			while `done' == 0 {
				capture confirm file "garbageIcd`v'Sex`s'Finished.txt"
				if _rc == 0 local done = 1
				else {
					sleep 30000
					display in yellow "." _c
				}
			}
		}
	}

// now that everything has finished running, put the pieces back together
	clear
	foreach s of local sexList {
		foreach v of local icdList {
			append using "`projDir'/data/cod/clean/redistributed/countyCFs_sex`s'_icd`v'.dta"
		}
	}

// save the final file
	save "`projDir'/data/cod/clean/redistributed/countyCFs.dta", replace

// delete temporary files
	foreach s of local sexList {
		foreach v of local icdList {
			capture rm "`projDir'/data/cod/clean/redistributed/countyCFs_sex`s'_icd`v'.dta"
			capture rm "`projDir'/logs/scratch/garbageIcd`v'Sex`s'Finished.txt"
			capture rm "`projDir'/logs/scratch/icd`v'Sex`s'/redistributeGarbage.log"
		}
	}
