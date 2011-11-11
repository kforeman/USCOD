
// For use with "format_mort.do"

//Recoding Race
// Details of these recordes can be found here: X:\projects\USBODI\8 Americas\excel_files\race groups 1960 - 2002.xls

/* OUTPUT IS A SINGLE VARIABLE RACE WITH 4 POSSIBLE VALUES. ALL OTHER RACE VARIABLES WILL BE DROPPED*/
	

	if `1'>=1962 & `1'<=1963 {

		replace race="11" if race=="X"

		}

	gen temprace = race
	destring temprace, replace
	
	if `1'>=1959 & `1'<=1961 {
		recode temprace (1=1) (2=2) (3 6 7 = 3) (4 5 8 9 10 11 = 4) 
		}			
		else  if `1'>=1962 & `1'<=1963 {										// "not stated" assumed to be asian 
			recode temprace (1=1) (2=2) (3 6 7 = 3) (4 5 8 9 11 0 = 4)
			}
			else if `1'>=1964 & `1'<=1967 {										/* race categories for years 1964 - 1967 */		
				recode temprace (1=1) (2=2) (3=3) (4/7 = 4) 					
				}
				else if `1'==1968 {												/* race categories for year 1968 */
						recode temprace (1=1) (2=2) (3=3) (4/7 = 4)											
						}
						else if `1'>=1969 & `1'<=1978 {							/* race categories for years 1969 - 1978 */	
							recode temprace (1=1) (2=2) (3=3) (0 4/8 = 4)			
							}
							else if `1'>=1979 & `1'<=1988 { 					/* race categories for years 1979 - 1988 */
								recode temprace (1=1) (2=2) (3=3) (0 4/8 = 4) 					
								}
								else if `1'>=1989 & `1'<=1991 {					/* race categories for years 1989 - 1991 */	
									recode temprace (1=1) (2=2) (3=3) (4/9 = 4) 					
									}
									else if `1'>=1992	{						/* race categories for years 1992 - 2004 */
										recode temprace (1=1) (2=2) (3=3) (4/78 = 4)		
										}
	drop race*
	rename temprace race
	
	
			{
		    cap drop obs
			gen obs = 1
			sum obs if race==.
	
			if r(sum)>0 {
				di "ERROR: race has missing values"
				}
			drop obs
			}

	
	count if race>4
	if `r(N)' {
	
			di "year `1': race still has greater 4 values"
	
	}
	
	
	
exit