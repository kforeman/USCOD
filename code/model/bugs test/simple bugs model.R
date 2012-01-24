# setup directory info
	proj <- 'USCOD'
	proj_dir <- ifelse(Sys.info()['sysname'] == 'Windows', paste('D:/projects', proj, sep='/'), paste('/shared/projects', proj, sep='/'))

# load in libraries
	setwd(paste(proj_dir, '/code/model/bugs test/', sep=''))
	library('R2WinBUGS')
	library('foreign')

# load in data
	cod <- read.dta(paste(proj_dir, '/data/model inputs/state_random_effects_input.dta', sep=''))

# keep just a specific age/sex
	sex <- 1
	age <- '60to74'
	cod <- cod[cod$sex == sex & cod$age_group == age, ]

# map states to indices
	states <- levels(as.factor(cod$stateFips))
	num_states <- length(states)
	cod$state <- NA
	for (j in 1:num_states) {
		cod[cod$stateFips == states[j], 'state'] <- j
	}

# map causes to indices
	causes <- levels(as.factor(cod$underlying))
	num_causes <- length(causes)
	cod$cause <- NA
	for (j in 1:num_causes) {
		cod[cod$underlying == causes[j], 'cause'] <- j
	}

# get rid of places with 0 population (because taking the log of 0 crashes bugs, it seems)
	cod <- cod[cod$pop > 0 & !is.na(cod$pop), ]

# keep just a subset for debugging
	cod <- cod[cod$cause <= 5 & cod$state <= 10, ]

# setup data for bugs
	num_obs <- dim(cod)[1]
	dth <- cod$deaths
	pop <- cod$pop
	year <- cod$year
	cause <- cod$cause
	state <- cod$state
	data <- list('num_obs', 'num_states', 'num_causes', 'dth', 'pop', 'year', 'cause', 'state')

# write data to disk
	bugs.data(data)

# list parameters to track
	parameters <- c('state_intercept', 'state_slope', 'cause_intercept', 'cause_slope')

# initial values
	inits <- function()
		list(
			state_intercept=rnorm(num_states, 0, 1),
			state_slope=rnorm(num_states, 0, 1),
			cause_intercept=rnorm(num_causes, 0, 1),
			cause_slope=rnorm(num_causes, 0, 1),
			mu_si=rnorm(1,0,100),
			sigma_si=runif(1,0,100),
			mu_ss=rnorm(1,0,100),
			sigma_ss=runif(1,0,100),
			mu_ci=rnorm(1,0,100),
			sigma_ci=runif(1,0,100),
			mu_cs=rnorm(1,0,100),
			sigma_cs=runif(1,0,100)
		)

# run in openbugs
	sim <- bugs('data.txt', inits, parameters, 'simple bugs model.bug', n.chains=1, n.iter=1000, program='openbugs')

# display the results
	print(sim)
	plot(sim)
