/*
Author:		Kyle Foreman
Created:	24 Jan 2011
Updated:	24 Jan 2011
Purpose:	plot results output by the pymc and glm models
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local proj_dir "D:/projects/`proj'"
	else local proj_dir "/shared/projects/`proj'"

// find cause names
	use "`proj_dir'/data/cod/clean/COD maps/uscod_names.dta", clear
	rename uscod cause
	tempfile cause_names
	save `cause_names', replace

// find state names
	insheet using "`proj_dir'/data/geo/clean/state_names.csv", comma clear
	levelsof statefips, l(fipses) c
	foreach f of local fipses {
		levelsof name if statefips == `f', l(state_`f') c
	}

// load in R glm estimates
	insheet using "`proj_dir'/outputs/model results/simple random effects by state/simple model results.csv", comma clear
	destring predicted, replace force
	drop if predicted == .
	sort age sex state year

// load in pymc estimates
	preserve
	insheet using "`proj_dir'/outputs/model results/simple random effects by state/pymc_results.csv", comma clear
	rename statefips state
	rename underlying cause
	rename age_group age
	keep sex cause year age state mean lower upper
	tempfile pymc
	save `pymc', replace
	restore

// combine estimates
	merge 1:1 sex cause year age state using `pymc', nogen keep(match)

// label causes
	merge m:1 cause using `cause_names', nogen keep(match)
	replace cause = subinstr(cause, "_", ".", .) + " " + upper(subinstr(short, "_", " ", .))

// find ages/sexes to loop through
	levelsof age, l(ages) c
	levelsof sex, l(sexes) c

// plot by age/sex/state
	set scheme s1color
	capture mkdir "`proj_dir'/outputs/model results/simple random effects by state/pdftemp"
	preserve
	local c = 1
	foreach a of local ages {
		foreach s of local sexes {
			local sx = cond(`s'==1, "Male", "Female")
			foreach f of local fipses {
				restore, preserve
				keep if age == "`a'" & sex == `s' & state == `f'
				if _N == 0 continue
				twoway rarea upper lower year, color(eltblue) sort || line predicted mean year, lcolor(cranberry edkblue) sort || scatter deaths year, mcolor(black) msymbol(oh) by(cause, yrescale style(compact) title("`a', `sx'" "`state_`f''")) legend(size(vsmall) order(4 2 3) label(4 "Observed") label(2 "GLM") label(3 "PyMC") rows(1))
				graph play remove_by_box
				graph export "`proj_dir'/outputs/model results/simple random effects by state/pdftemp/`c'.pdf", replace
				local c = `c' + 1
			}
		}
	}
	!"C:/ado/pdftk/pdftk.exe" "`proj_dir'/outputs/model results/simple random effects by state/pdftemp/*.pdf" cat output "`proj_dir'/outputs/model results/simple random effects by state/model comparison.pdf"
	!rmdir "`proj_dir'/outputs/model results/simple random effects by state/pdftemp/" /q /s
