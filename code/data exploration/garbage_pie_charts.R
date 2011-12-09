# Author:	Kyle Foreman
# Created:	8 December 2011
# Updated:	9 December 2011
# Purpose:	make a pie charts of where garbage is going

# setup directory info for this project
	proj <- 'USCOD'
	proj_dir <- ifelse(Sys.info()['sysname'] == 'Windows', paste('D:/projects', proj, sep='/'), paste('/shared/projects', proj, sep='/'))

# setup parameters specific to this code
	icd_list = c(9, 10)
	sex_list = c(1, 2)

# find list of causes of death
	library(foreign)
	uscod_list <- read.dta(paste(proj_dir, 'data/cod/clean/COD maps/USCOD_names.dta', sep='/'))
	uscod_list <- uscod_list[nchar(uscod_list$uscod) > 1,]

# add a color for each cause of death
	uscod_list[substr(uscod_list$uscod, 1, 1) != 'G', 'color'] <- rainbow(length(uscod_list[substr(uscod_list$uscod, 1, 1) != 'G', 'uscod']))

# add a row for the remainder column
	uscod_list <- rbind(uscod_list, c('Remainder', 'Remainder', '#FFFFFFFF'))

# list of age groups in the desired plot order
	age_list <- c('All Ages', 'Under 15', '15 to 29', '30 to 44', '45 to 59', '60 plus')

# open a pdf 
	pdf(file=paste(proj_dir, 'outputs/data exploration/garbage/garbage_pie_charts.pdf', sep='/'), width=14, height=8)
	par(mfrow=c(2,3), oma=c(0, 0, 1, 0))
	library(ggplot2)

# loop through the packages
	for (g in unique(uscod_list[substr(uscod_list$uscod,1,1)=='G','uscod'])) {
		for (s in sex_list) {
			for (v in icd_list) {
				if (g == 'G_9' & v == 9) next
				
			# load in the redistribution results
				g_data <- read.dta(paste(proj_dir, '/data/cod/clean/redistributed/redistributed_sex', s, '_icd', v, '_GC', g, '.dta', sep=''))
				g_data <- g_data[complete.cases(g_data),]
			
			# add in age groups
				g_data$age_group <- g_data$age
				g_data[g_data$age < 15, 'age_group'] <- 'Under 15'
				g_data[15 <= g_data$age & g_data$age <= 29, 'age_group'] <- '15 to 29'
				g_data[30 <= g_data$age & g_data$age <= 44, 'age_group'] <- '30 to 44'
				g_data[45 <= g_data$age & g_data$age <= 59, 'age_group'] <- '45 to 59'
				g_data[60 <= g_data$age, 'age_group'] <- '60 plus'
			
			# find how many years this data covers
				num_years <- length(unique(g_data$year))
			
			# collapse to national proportions
				all_ages <- aggregate(deaths ~ underlying, g_data, sum)
				by_age <- aggregate(deaths ~ age_group + underlying, g_data, sum)
				all_ages$age_group <- 'All Ages'
				by_cause <- rbind(all_ages, by_age)
			
			# find proportion
				totals <- aggregate(deaths ~ age_group, by_cause, sum)
				by_cause <- merge(by_cause, totals, by='age_group')
				by_cause$proportion <- by_cause$deaths.x / by_cause$deaths.y
			
			# clump small recipients together
				by_cause[by_cause$proportion < .01, 'underlying'] <- 'Remainder'
				by_cause <- aggregate(proportion ~ age_group + underlying, by_cause, sum)
			
			# add on colors/names
				pie_input <- merge(by_cause, uscod_list, by.x='underlying',by.y='uscod')
			
			# draw a pie for each age group
				for (a in age_list) {
					d <- pie_input[pie_input$age_group == a,]
					if (dim(d)[1] ==0) {
						plot.new()
						next
					}
					pie(d$proportion, labels=d$uscodName, col=d$color, main=paste(a, '\n', comma(round(totals[totals$age_group == a, 'deaths'] / num_years)), 'deaths/year'))
				}
				title(paste(uscod_list[uscod_list$uscod==g, 'uscodName'], 'ICD', v, ifelse(s==1, 'Male', 'Female')), outer=TRUE)
			}
		}
	}
	dev.off()
