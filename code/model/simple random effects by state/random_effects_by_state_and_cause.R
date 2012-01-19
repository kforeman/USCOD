# Author:	Kyle Foreman
# Created:	17 January 2011
# Updated:	17 January 2011
# Purpose:	run a simple random effects model with random intercepts on state/cause and slopes on year

# setup directory info for this project
	proj <- 'USCOD'
	proj_dir <- ifelse(Sys.info()['sysname'] == 'Windows', paste('D:/projects', proj, sep='/'), paste('/shared/projects', proj, sep='/'))

# update the input data? (only necessary if you have rerun redistribution)
	update_data <- 0

# load libraries
	library(foreign)
	library(lme4)

# run the Stata program to update the data (I have no idea why R is so painfully slow at using 'aggregate' compared to 'collapse' in Stata - like, literally several orders of magnitude slower, I just gave up)
	if (update_data == 1) system(paste('"C:/Program Files (x86)/Stata12/StataMP-64.exe" /e do "', proj_dir, '/code/model/simple random effects by state/prep_random_effects_dataset.do"', sep=''), wait=TRUE)

# load in redistributed deaths
	data <- read.dta(paste(proj_dir, '/data/model inputs/state_random_effects_input.dta', sep=''))

# convert strings to factors
	data$state <- as.factor(data$stateFips)
	data$age <- as.factor(data$age_group)
	data$cause <- as.factor(data$underlying)
	data$stateFips <- data$age_group <- data$underlying <- NULL

# store levels of cause/state for looping through random effects
	states <- levels(data$state)
	causes <- levels(data$cause)

# make a placeholder for predictions
	models <- list()
	for (v in c('intercept', 'state_intercept', 'state_slope', 'cause_intercept', 'cause_slope')) data[v] <- NA
	
# use log of population as the offset
	data$offset <- log(data$pop)

# loop through age and sex
	for (a in c('Under5', '5to14', '15to29', '30to44', '45to59', '60to74', '75plus')) {
		for (s in c(1, 2)) {
	
		# find indices for the current age/sex
			ii <- data$age == a & data$sex == s
			
		# run the model
			print(paste(a, s))
			m <- lmer(deaths ~ 1 + offset(offset) + (1 + year | state) + (1 + year | cause), data[ii, ], family='poisson')
			try(print(summary(m)))
			#models[paste(a, s, sep='_')] <- m

		# fill in the estimated effects
			try(data$intercept[ii] <- summary(m)@fixef)
			for (st in states) try(data[ii & data$state == st, c('state_intercept', 'state_slope')] <- ranef(m)$state[st, ])
			for (c in causes) try(data[ii & data$cause == c, c('cause_intercept', 'cause_slope')] <- ranef(m)$cause[c, ])
		}
	}

# create the overall predictions
	data$predicted <- exp(data$offset + data$intercept + data$state_intercept + (data$year * data$state_slope) + data$cause_intercept + (data$year * data$cause_slope))

# save predictions
	write.csv(data, file=paste(proj_dir, '/outputs/model results/simple random effects by state/simple model results.csv', sep=''))
