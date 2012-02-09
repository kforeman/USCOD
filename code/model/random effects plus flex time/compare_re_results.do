/*
Author:		Kyle Foreman
Created:	24 Jan 2011
Updated:	09 Feb 2011
Purpose:	compare simple RE and RW models
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

// load in old RE pymc estimates
	insheet using "`proj_dir'/outputs/model results/simple random effects by state/pymc_results.csv", comma clear
	rename statefips state
	rename underlying cause
	rename age_group age
	keep sex cause year age state mean lower upper deaths
	rename mean re_mean
	rename lower re_lower
	rename upper re_upper

// load in new RW pymc estimates
	preserve
	insheet using "`proj_dir'/outputs/model results/random effects plus flex time/pymc_results.csv", comma clear
	drop state cause
	rename statefips state
	rename underlying cause
	rename age_group age
	keep sex cause year age state mean lower upper
	rename mean rw_mean
	rename lower rw_lower
	rename upper rw_upper
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
	capture mkdir "`proj_dir'/outputs/model results/random effects plus flex time/pdftemp"
	preserve
	local c = 1
	foreach a of local ages {
		foreach s of local sexes {
			local sx = cond(`s'==1, "Male", "Female")
			foreach f of local fipses {
				restore, preserve
				keep if age == "`a'" & sex == `s' & state == `f'
				if _N == 0 continue
				twoway rarea re_upper re_lower year, color(erose) sort || rarea rw_upper rw_lower year, color(eltblue) sort || line re_mean rw_mean year, lcolor(cranberry edkblue) sort || scatter deaths year, mcolor(black) msymbol(oh) by(cause, yrescale style(compact) title("`a', `sx'" "`state_`f''")) legend(size(vsmall) order(5 3 4) label(5 "Observed") label(3 "Old Model (RE)") label(3 "New Model (RW + drift)") rows(1))
				graph play remove_by_box
				graph export "`proj_dir'/outputs/model results/random effects plus flex time/pdftemp/`c'.pdf", replace
				local c = `c' + 1
			}
		}
	}
	!"C:/ado/pdftk/pdftk.exe" "`proj_dir'/outputs/model results/random effects plus flex time/pdftemp/*.pdf" cat output "`proj_dir'/outputs/model results/random effects plus flex time/model comparison.pdf"
	!rmdir "`proj_dir'/outputs/model results/random effects plus flex time/pdftemp/" /q /s
