'''
Author:		Kyle Foreman
Created:	17 February 2012
Updated:	17 February 2012
Purpose:	find states' neighbors
'''

# import libraries
import pysal
import os

# setup directory info
project =   'USCOD'
proj_dir =  'D:/Projects/' + project +'/' if (os.environ['OS'] == 'Windows_NT') else '/shared/projects/' + project + '/'

# create border matrix
# data from http://www.nws.noaa.gov/geodata/catalog/national/html/us_state.htm
noaa = pysal.rook_from_shapefile(proj_dir + 'data/geo/raw/NOAA/s_01ja11.shp', 'Fips').full()

# store the mapping of states to indices
geo_lookup = noaa[1]

# store border matrix
border_mat = noaa[0]

# find how many states border each
num_bordering = np.sum(border_mat, axis=0)

# find (bordering == 1) / num_bordering
weighted_border = (border_mat / num_bordering).T
weighted_border[np.isnan(weighted_border)] = 0.