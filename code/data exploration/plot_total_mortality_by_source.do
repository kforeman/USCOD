/*
Author:		Kyle Foreman
Created:	12 December 2011
Updated:	12 December 2011
Purpose:	compare total mortality numbers by source of data
*/

// setup directory info for this project
	local proj "USCOD"
	if c(os) == "Windows" local projDir "D:/projects/`proj'"
	else local projDir "/shared/projects/`proj'"

// load in redistributed deaths by state
	use "`projDir'/data/cod/clean/redistributed/redistributed.dta", clear
	keep if inrange(age, 0, 85) & underlying != "T"

// collapse down to national trends
	collapse (sum) deaths, by(year)
	rename deaths kyle_deaths_rd

// add on unredistributed deaths by state
	preserve
	use "`projDir'/data/cod/clean/deaths by USCOD/stateDeaths.dta", clear
	keep if inrange(age, 0, 85) & uscod != "T"
	collapse (sum) deaths, by(year)
	rename deaths kyle_deaths_raw
	tempfile unrd
	save `unrd', replace
	restore
	merge 1:1 year using `unrd', nogen

// add on Sandeep's raw numbers
	preserve
	clear
	forvalues i = 1979 / 2007 {
		append using "`projDir'/data/cod/raw/USBOD/mort_acs/usbodi`i'.dta"
	}
	egen sandeep_deaths_raw = rowtotal(_*)
	collapse (sum) sandeep_deaths_raw, by(year)
	tempfile sdun
	save `sdun', replace
	restore
	merge 1:1 year using `sdun', nogen

// add on Sandeep's redistributed
	preserve
	clear
	forvalues i = 1990 / 2005 {
		append using "`projDir'/data/cod/raw/USBOD/garbdist/garbdist`i'.dta"
	}
	egen sandeep_deaths_rd = rowtotal(_*)
	collapse (sum) sandeep_deaths_rd, by(year)
	tempfile sdrd
	save `sdrd', replace
	restore
	merge 1:1 year using `sdrd', nogen

// plot totals
	set scheme tufte
	scatter kyle_deaths_raw kyle_deaths_rd sandeep_deaths_raw sandeep_deaths_rd year, xline(1998.5, lcolor(black)) msymbol(+ oh x th) msize(2 2 2 2) mcolor(ebblue blue pink red) legend(label(1 "Kyle (raw)") label(2 "Kyle (redistributed)") label(3 "Sandeep (raw)") label(4 "Sandeep (redistributed)") rows(2)) ytitle("Total Deaths") xtitle("Year") title("All Cause Mortality Comparison by Source")
	graph export "`projDir'/outputs/data exploration/scratch/totals_compared.pdf", replace
