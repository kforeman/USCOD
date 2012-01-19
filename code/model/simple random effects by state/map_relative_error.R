# Author:	Kyle Foreman
# Created:	18 January 2011
# Updated:	18 January 2011
# Purpose:	map the relative error from the random effects model

# setup directory info for this project
	proj <- 'USCOD'
	proj_dir <- ifelse(Sys.info()['sysname'] == 'Windows', paste('D:/projects', proj, sep='/'), paste('/shared/projects', proj, sep='/'))
	
# load in libraries
	library(foreign)
	library(ggplot2)
	library(maps)

# get the state data
	map_states <- map_data('state')
	fips_to_state <- read.csv(paste(proj_dir, '/data/geo/clean/state_names.csv', sep=''))

# load in model results
	results <- read.csv(paste(proj_dir, '/outputs/model results/simple random effects by state/simple model results.csv', sep=''))

# keep just 2003-2007
	results <- results[results$year >= 2003 & results$year <= 2007, ]

# add on state names
	results$state_name <- ''
	for (i in 1:length(fips_to_state$name)) {
		results[results$state == fips_to_state[i, 'stateFips'], 'state_name'] <- tolower(fips_to_state[i, 'name'])
	}

# find the relative error for 2003-2007
	results <- aggregate(cbind(deaths, predicted) ~ cause + state_name + age + sex, results, FUN=mean)
	results$rel_err <- (results$predicted - results$deaths) / results$deaths
	results$rel_err[results$rel_err == Inf] <- NA

# function to take a value and return its index in a corresponding list of quantiles
	find_bin <- function(val, qs) {
		if (is.na(val)) 				return(round(length(qs)/2))
		else if (val <= qs[1])			return(1)
		else if (val > qs[length(qs)])	return(length(qs))
		else {
			for (i in 2:length(qs)) {
				if (val <= qs[i] & val > qs[i-1]) return(i)
			}
		}
	}

# function to turn a bunch of plots into small multiples
	vp.layout <- function(x, y) viewport(layout.pos.row=x, layout.pos.col=y)
	arrange <- function(plots, title='') {
		n <- length(plots)
		nrow = ceiling(sqrt(n))
		ncol = ceiling(n/nrow)
		grid.newpage()
		pushViewport(viewport(layout=grid.layout(nrow,ncol) ) )
		ii.p <- 1
		for(ii.row in seq(1, nrow)){
			ii.table.row <- ii.row 
			for(ii.col in seq(1, ncol)){
				ii.table <- ii.p
				if(ii.p > n) break
				print(plots[[ii.table]], vp=vp.layout(ii.table.row, ii.col))
				ii.p <- ii.p + 1
			}
		}
		grid.text(title, y=.98, gp=gpar(fontsize=16))
	}

# cause names
	causes <- levels(results$cause)
	cause_list <- read.dta(paste(proj_dir, 'data/cod/clean/COD maps/USCOD_names.dta', sep='/'))	
	
# loop through age/sex
	for (a in c('Under5', '5to14', '15to29', '30to44', '45to59', '60to74', '75plus')) {
		for (s in c(1, 2)) {
		
		# make sure we have data for this age/sex
			if (length(results[results$age == a & results$sex == s, 'rel_err']) == 0) next

		# open a pdf
			pdf(file=paste(proj_dir, '/outputs/model results/simple random effects by state/relative error maps/', a, '_', ifelse(s==1, 'Male', 'Female'),'.pdf', sep=''), width=14, height=8)
		
		# start storing the plots for this age/sex combo
			plots <- list()
		
		# loop through cause
			for (cs in 1:length(causes)) {
		
			# filter out the data
				d <- results[results$age == a & results$sex == s & results$cause == causes[cs], ]
				if (length(d$rel_err) == 0) next
			
			# find quantiles for this subset
				qs <- quantile(d$rel_err, seq(.05,.95,.1), na.rm=TRUE)
			
			# bin colors by quantile
				d$color <- NA
				for (i in 1:length(d$color)) {
					d[i, 'color'] <- toString(find_bin(d[i, 'rel_err'], qs))
				}
			
			# merge relative errors onto the map data
				md <- merge(map_states, d, by.x='region', by.y='state_name')
				md <- md[order(md$order), ]
			
			# create the map
				# start plot
					map <- ggplot(md, aes(long,lat,group=group)) 
				# add fills for choropleth
					map <- map + geom_polygon(aes(fill=color)) + scale_fill_brewer(palette='BrBG')
				# change projection
					map <- map + coord_map(project='globular') 
				# add outlines 
					map <- map + geom_path(data=map_states, colour='white', size=.5)
				# remove a bunch of default map things to make it look cleaner
					map <- map + 
							scale_x_continuous(breaks = NA) +
							scale_y_continuous(breaks = NA) +
							opts(
								legend.position = 'none',
								panel.grid.major = theme_blank(),
								panel.grid.minor = theme_blank(),
								panel.background = theme_blank(),
								panel.border = theme_blank(),
								axis.ticks = theme_blank(),
								axis.title.x = theme_blank(),
								axis.title.y = theme_blank()
							)
				# add a title for the cause
					cl <- cause_list[cause_list$uscod == causes[cs], ]
					map <- map + opts(title=paste(gsub('_', '.', cl$uscod), toupper(gsub('_', ' ', cl$short_name))))
				# add the map to the chart
					plots[[cs]] <- map
			}
		# plot all the causes for this age/sex together
			arrange(plots, title=paste(a, ifelse(s==1, 'Male', 'Female'), sep=', '))
		# close the pdf
			dev.off()
		}
	}
	
