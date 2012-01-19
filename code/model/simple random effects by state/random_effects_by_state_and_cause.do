/*
Author:		Kyle Foreman
Created:	17 January 2011
Updated:	17 January 2011
Purpose:	run a simple random effects model with random intercepts on state/cause and slopes on year
Notes:		see http://blog.stata.com/tag/mixed-models/ for details on how this model is fit using Stata
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local proj_dir "D:/projects/`proj'"
	else local proj_dir "/shared/projects/`proj'"

// prep the dataset
	do "`proj_dir'/code/model/simple random effects by state/prep_random_effects_dataset.do"

// create placeholder variables for the predictions
	generate prediction = .

// create dummies by state and interactions with year
// see http://blog.stata.com/tag/mixed-models/ for an explanation of why we do this
	tab stateFips, generate(state_)
	unab idvar: state_*
	foreach v of local idvar {
		generate slope_`v' = year * `v'
	}

// loop through age and sex
	foreach a in "Under5" "5to14" "15to29" "30to44" "45to59" "60to75" "75plus" {
		foreach s in 1 2 {
			local sx = cond(`s'==1, "Male", "Female")
			keep if age_group == "`a'" & sex == `s'
			
		// run the regression
			xtmepoisson deaths year || _all: R.stateFips || _all: slope_*, cov(identity) nocons || underlying: year
	
		// hmmm, seldom actually converges in Stata, switching to R
	
	
	
	
	
	
	
		}
	}
