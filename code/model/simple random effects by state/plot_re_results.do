/*
Author:		Kyle Foreman
Created:	18 January 2011
Updated:	18 January 2011
Purpose:	plot results output by the R model
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

// load in estimates
	insheet using "`proj_dir'/outputs/model results/simple random effects by state/simple model results.csv", comma clear
	destring predicted, replace force
	drop if predicted == .
	sort age sex state year

// label causes
	merge m:1 cause using `cause_names', nogen keep(match)
	replace cause = subinstr(cause, "_", ".", .) + " " + upper(subinstr(short, "_", " ", .))

// plot by age/sex/state
	set scheme s1color
	capture mkdir "`proj_dir'/outputs/model results/simple random effects by state/pdftemp"
	preserve
	local c = 1
	foreach a in "Under5" "5to14" "15to29" "30to44" "45to59" "60to75" "75plus" {
		foreach s in 1 2 {
			local sx = cond(`s'==1, "Male", "Female")
			foreach f of local fipses {
				restore, preserve
				keep if age == "`a'" & sex == `s' & state == `f'
				if _N == 0 continue
				scatter deaths year, by(cause, yrescale style(compact) title("`a', `sx'" "`state_`f''")) mcolor(blue) || line predicted year, lcolor(red) sort legend(size(vsmall) label(1 "Observed") label(2 "Predicted"))
				graph play remove_by_box
				graph export "`proj_dir'/outputs/model results/simple random effects by state/pdftemp/`c'.pdf", replace
				local c = `c' + 1
			}
		}
	}
	!"C:/ado/pdftk/pdftk.exe" "`proj_dir'/outputs/model results/simple random effects by state/pdftemp/*.pdf" cat output "`proj_dir'/outputs/model results/simple random effects by state/simple_RE_model.pdf"
	!rmdir "`proj_dir'/outputs/model results/simple random effects by state/pdftemp/" /q /s
