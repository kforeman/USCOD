# Author:	Kyle Foreman
# Date:		24 Feb 2012
# Purpose:	Simple LOESS model of cause-specific mortality for creating visualizations

# load in the data
	library(foreign)
	proj_dir <- 'D:/projects/USCOD/'
	data <- 	read.dta(paste(proj_dir, 'data/model inputs/state_random_effects_input.dta', sep=''))

# make lists of causes/ages/states/sexes to loop through
	causes <-	unique(data$underlying)
	states <- 	unique(data$stateFips)
	ages <- 	unique(data$age_group)
	sexes <-	unique(data$sex)

# index everything
	cause_indices <-	matrix(nrow=length(data$year), ncol=length(causes))
	for (i in 1:length(causes)) {
		cause_indices[,i] <-	data$underlying == causes[i]
	}
	state_indices <-	matrix(nrow=length(data$year), ncol=length(states))
	for (i in 1:length(states)) {
		state_indices[,i] <-	data$stateFips == states[i]
	}
	age_indices <-		matrix(nrow=length(data$year), ncol=length(ages))
	for (i in 1:length(ages)) {
		age_indices[,i] <-		data$age_group == ages[i]
	}
	sex_indices <-		matrix(nrow=length(data$year), ncol=length(sexes))
	for (i in 1:length(sexes)) {
		sex_indices[,i] <-		data$sex == sexes[i]
	}

# create log death rates
	data$ln_rate <- log(data$deaths / data$pop * 100000)
	data$ln_rate[is.infinite(data$ln_rate) | data$ln_rate < -10] <- -10

# create vectors to store the prediction in
	prediction <- 	pred_se	<- 	rep(NA, length(data$year))

# loop through the causes/states/ages/sexes
	for (c in 1:length(causes)) {
		for (s in 1:length(states)) {
			print(paste(causes[c], states[s]))
			for (a in 1:length(ages)) {
				for (x in 1:length(sexes)) {
				
				# pull out the relevant data
					i <-	cause_indices[,c] & state_indices[,s] & age_indices[,a] & sex_indices[,x]
					d <-	data[i,]
				
				# run loess
					lo <-	loess(ln_rate ~ year, d)
				
				# predict with standard error
					p <-	predict(lo, d$year, se=TRUE)
					prediction[i]	<- p$fit
					pred_se[i]		<- p$se.fit
				}
			}
		}
	}

# add mean prediction (because taking the mean of the draws - after converting to ln(rate) space - would systematically bias upwards in death space)
	data['mean'] <- exp(prediction) * data$pop / 100000

# create 100 draws of predicted deaths
	for (i in 1:100) {
		data[paste('draw', i, sep='')] <- exp(prediction + rnorm(n=1, mean=0, sd=pred_se)) * data$pop / 100000
	}

# save predictions
	write.csv(data, paste(proj_dir, 'outputs/model results/simple loess/simple_loess_in_R.csv', sep=''))
