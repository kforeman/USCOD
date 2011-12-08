/*
Author:		Kyle Foreman
Created:	27 October 2011
Updated:	10 November 2011
Purpose:	run the redistribution for both icd versions and sexes in parallel (Windows only for right now...)
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// setup parameters specific to this code
	local icdList 9 10
	local sexList 1 2

// load in cause list
	use "`projDir'/data/cod/clean/COD maps/USCOD_names.dta", clear
	keep if substr(uscod, 1, 1) == "G" & length(uscod) > 1
	levelsof uscod, l(garbageList) c

// change to the scratch log directory so that outputs will be stored there
	cd "`projDir'/logs/scratch/"

// loop through the sexes
	local counter = 0
	foreach s of local sexList {
	
	// loop through icd versions
		foreach v of local icdList {
		
		// loop through garbage codes
			foreach g of local garbageList {
			
			// make a directory to store scratch files for the currently running file (stupid stata won't let you override where it saves its awful default logs, meaning if you run the same program with different arguments it gets disk read slowness...)
				capture mkdir "icd`v'Sex`s'GC`g'"
				cd "icd`v'Sex`s'GC`g'"

			// delete the temporary file signifying this program has completed in case it still exists from a previous attempt
				capture rm "garbageIcd`v'Sex`s'GC`g'Finished.txt"
		
			// start running the program
				winexec "C:/Program Files (x86)/Stata12/StataMP-64.exe" /e do \"`projDir'/code/garbage redistribution/redistribute_garbage_logit_model.do\" `g' `v' `s'
		
			// switch back to the main scratch directory
				cd ..
			
			// wait 30 minutes between each batch of 3
				local counter = `counter' + 1
				if !mod(`counter', 3) sleep 1800000
			}
		
		}
	}

// convert the original data into the right format, sans garbage
	use "`projDir'/data/cod/clean/garbage inputs/matchingTestDataset.dta", clear
	drop if substr(underlying, 1, 1) == "G"
	keep sex age year mcounty underlying stateFips
	generate deaths = 1
	collapse (sum) deaths, by(sex age year mcounty underlying stateFips)

// loop through each sex/icd version and don't proceed until it's done running
	foreach s of local sexList {
		foreach v of local icdList {
			foreach g of local garbageList {
				local done = 0
				while `done' == 0 {
					capture confirm file "garbageIcd`v'Sex`s'GC`g'Finished.txt"
					if _rc == 0 local done = 1
					else {
						sleep 30000
						display in yellow "." _c
					}
				}
			}
		}
	}

// now that everything has finished running, add the garbage back on
	foreach s of local sexList {
		foreach v of local icdList {
			foreach g of local garbageList {
				capture append using "`projDir'/data/cod/clean/redistributed/redistributed_sex`s'_icd`v'_GC`g'.dta"
			}
		}
	}

// resum the deaths now that redistributed are added on
	collapse (sum) deaths, by(sex age year mcounty underlying stateFips)

// save the final CF file
	compress
	save "`projDir'/data/cod/clean/redistributed/redistributed.dta", replace

// delete temporary files
	foreach s of local sexList {
		foreach v of local icdList {
			foreach g of local garbageList {
				capture rm "`projDir'/logs/scratch/garbageIcd`v'Sex`s'GC`g'Finished.txt"
				!rmdir "`projDir'/logs/scratch/icd`v'Sex`s'GC`g'/" /s /q
			}
		}
	}

