/* Note: this code is taken from Sandeep Kulkarni's USBOD project, modified slightly for some small bug fixes */

pause on
// For use with "format_mort.do"

// FIP & mcounty
// Before 1982, the mortality files do not use standard FIP codes to identify counties instead uses a different set of county identifying codes.
// These codes can be found in the support information for the mortality files. Merge maps corresponding to these maps have been made.


/* part 1: creation of FIPS or FIPS equivalent */

	if `1'>=1959 & `1'<=1961 {
		
		drop if countyoccres== "ZZZ"
		
		destring stoccres, replace
		destring countyoccres, replace
		
		/*drop if stoccres>56*/				/*drop residents outside of 51 states*/
		/*drop if countyoccres==0*/			/*drop foreign residents*/
		drop if stoccres==0					/*drop foreign residents*/
		tostring countyoccres, replace
		tostring stoccres, replace
		gen lenst=length(stoccres)
		gen lencnty=length(countyoccres)
		replace stoccres="0"+stoccres if lenst==1
		replace countyoccres="00"+countyoccres if lencnty==1
		replace countyoccres="0"+countyoccres if lencnty==2
		drop lenst lencnty
		egen fips=concat(stoccres countyoccres)
		}

	else if `1'>=1962 & `1'<=1967 {
		
		drop if countyoccres== "ZZZ"
		
		destring stoccres, replace
		destring countyoccres, replace
		drop if stoccres>=52				/* drop residents outside of 51 states */
		/* drop if countyoccres==0 */			/* drop foreign residents */
		drop if stoccres==0					/* drop foreign residents */
		tostring countyoccres, replace
		tostring stoccres, replace
		gen lenst=length(stoccres)
		gen lencnty=length(countyoccres)
		replace stoccres="0"+stoccres if lenst==1
		replace countyoccres="00"+countyoccres if lencnty==1
		replace countyoccres="0"+countyoccres if lencnty==2
		drop lenst lencnty
		egen fips=concat(stoccres countyoccres)

		}

	else if `1'>=1968 & `1'<=1981 {	
	
		drop if countyres == "ZZZ"
	
		destring stateres, replace		
		destring countyres, replace
		drop if stateres >= 52			/* drop residents outside of 51 states */
		/* drop if countyres==0 */		/* drop foreign residents */
		drop if stateres==0				/* drop foreign residents */
		tostring countyres, replace
		
		/* it appears that Sandeep's map (at least this version of it) is wrong for 1979-1981, maybe earlier years too... these state mappings I have taken from the 1979 MCD documentation: */
		rename stateres old_codes
		merge m:1 old_codes using "$merge/old-codes-fips.dta", keep(match) nogen
		rename fips_codes stateres
		
		
		tostring stateres, replace
		gen lenst=length(stateres)
		gen lencnty=length(countyres)
		replace stateres="0"+stateres if lenst==1
		replace countyres="00"+countyres if lencnty==1
		replace countyres="0"+countyres if lencnty==2
		drop lenst lencnty
		egen fips=concat(stateres countyres)

		}
	
	else if `1'>=1982 & `1'<=1999 {	
		drop if countyres == "ZZZ"
		cap destring stateres, replace
		cap destring countyres, replace
																							/* MAY NEED TO BE MODIFIED BASED ON HOW fips VARIABLES ARE INFIXED */
		
		cap confirm numeric variable stateres countyres
			if _rc!=0 {
				di "countyres_fips or stateres_fips contains non-numeric values"
				pause
				}
		
		drop if stateres	> 56				/* drop residents outside of 51 states */
		drop if countyres	== 0			/* drop foreign residents */
		drop if stateres	== 0				/* drop foreign residents */
		tostring countyres, replace
		tostring stateres, replace
		
		
		// 1991 has the state code appended to the county for some reason
		if `1' == 1991 replace countyres = substr(countyres,3,3)
		
		
		gen lenst=length(stateres)
		gen lencnty=length(countyres)
		replace stateres = "0" + stateres if lenst==1
		replace countyres = "00"+ countyres if lencnty==1
		replace countyres = "0" + countyres if lencnty==2
		replace countyres = countyocc if countyres == "999" & stateres == "13"
		drop lenst lencnty
		egen fips=concat(stateres countyres)

		}
	
	else if `1'>=2000 & `1' <=2001 {	
		/* cap drop countyres
		cap drop stateres
		
		ren fipstres stateres
		ren fipcntyres countyres */
		rename countyres_fips countyres
		rename stateres_fips stateres
		
		drop if countyres == "ZZZ"
		drop if stateres == "ZZ"
	
		gen postal = stateres
		destring postal, replace
		
			cap confirm numeric variable postal
			if _rc!=0 {
				drop if postal == "ZZ"	/* CODE FOR 2003 and 2004, where numeric fips codes not provided*/
				drop stateres
				sort postal
				/* merge postal using "$merge/postal-fips.dta"
					tab _merge
									
					keep if _merge==3	
					drop _merge */
				merge m:1 postal using "$merge/postal-fips.dta", keep(match) nogen
				drop name postal
				rename fips stateres
				}
		
		destring stateres, replace
		destring countyres, replace
		drop if stateres >56				/* drop residents outside of 51 states*/
		drop if countyres == 0			/* drop foreign residents*/
		drop if stateres == 0				/* drop foreign residents*/
		tostring countyres, replace
		tostring stateres, replace
		gen lenst=length(stateres)
		gen lencnty=length(countyres)
		replace stateres 	= "0"+ stateres if lenst==1
		replace countyres = "00"+ countyres if lencnty==1
		replace countyres =	"0"+ countyres if lencnty==2
		drop lenst lencnty
		replace countyres = countyocc if countyres == "999" & stateres == "13"
		egen fips=concat(stateres countyres)
		}


	else if `1'>=2002 {

		drop if countyres == "ZZZ"
		drop if stateres == "ZZ"
	
		gen postal = stateres
		destring postal, replace
		
			cap confirm numeric variable postal
			if _rc!=0 {
				drop if postal == "ZZ"							
				/* CODE FOR 2003 and 2004, where numeric fips codes not provided*/
				drop stateres
				sort postal
				/* merge postal using "$merge/postal-fips.dta"
					tab _merge
									
					keep if _merge==3	
					drop _merge */
				merge m:1 postal using "$merge/postal-fips.dta", keep(match) nogen
				drop name postal
				rename fips stateres
				}
		
		destring stateres, replace
		destring countyres, replace
		drop if stateres >56				/* drop residents outside of 51 states*/
		drop if countyres == 0			/* drop foreign residents*/
		drop if stateres == 0				/* drop foreign residents*/
		tostring countyres, replace
		tostring stateres, replace
		gen lenst=length(stateres)
		gen lencnty=length(countyres)
		replace stateres 	= "0"		+ stateres		if lenst==1
		replace countyres = "00"	+ countyres		if lencnty==1
		replace countyres =	"0"		+ countyres		if lencnty==2
		drop lenst lencnty
		replace countyres = countyocc if countyres == "999" & stateres == "13"
		egen fips=concat(stateres countyres)
		}

	exit