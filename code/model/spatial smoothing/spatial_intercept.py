'''
Author:		Kyle Foreman
Created:	22 February 2012
Updated:	22 February 2012
Purpose:	fit smoothed RW with interactions model, adding in spatial smoothing
'''

### model specification
'''
    deaths[s,c,t]   ~ Poisson(y[s,c,t])
        
        s   : state (plus DC)
                0:50
        c   : cause of death
                0:23
        t   : year
                0:38 (1979:2007)


    y[s,c,t=n]  ~ exp(alpha + gamma*n + exposure + B_hat[s] + B[c] + B[s,c] + d[s]*n + d[c]*n + sum(u[s,t=0:n]) + sum(u[c,t=0:n]))
        
        alpha   ~ N(0, 1e-4)
                    roughly the average log mortality rate
        gamma   ~ N(0, 1e-4)
                    annual change in average log mortality rate
        exposure: ln(pop[s,c,t])
        B_hat[s]~ N(0, 1/sigma_b_s^2)
                    random intercept by state, spatially smoothed
        B[c]    ~ N(0, 1/sigma_b_c^2)
                    random intercept by cause
        B[s,c]  ~ N(0, 1/sigma_b_sc^2)
                    random intercept by cause/state interaction
        d[s]    ~ N(0, 1/sigma_d_s^2)
                    temporal drift by state (ie random slope)
        d[c]    ~ N(0, 1/sigma_d_c^2)
                    temporal drift by cause (ie random slope)
        u[s,t]  ~ N(0, 1/sigma_u_s^2)
                    random walk in time by state
                    sampled at 5 years intervals then interpolated via cubic spline
        u[c,t]  ~ N(0, 1/sigma_u_c[c]^2)
                    random walk in time by cause
                    sampled at 5 years intervals then interpolated via cubic spline


    hyperpriors
        
        B0[s]   : random intercept by state
            sigma_b_s   ~ U(0, 1e2)
        
        B0[c]   : random intercept by cause
            sigma_b_c   ~ U(0, 1e2)
        
        B0[s,c] : random intercept by state/cause interaction
            sigma_b_sc  ~ U(0, 1e2)
            
        u[s,t]  : random walk by state
            sigma_u_s   ~ U(0, 1e2)
        
        u[c,t]  : random walk by cause
            sigma_u_c[c]~ U(0, 1e2)
            # note: may want to put a distribution on sigma_u_c instead
        
        d[s]    : temporal drift by state
            sigma_d_s   ~ U(0, 1e2)
        
        d[c]    : temporal drift by cause
            sigma_d_c   ~ U(0, 1e2) 
'''

### define which model to run
# sex? (1 = Male, 2 = Female)
sex =   2
# age? (Under5, 5to14, 15to29, 30to44, 45to59, 60to74, 75plus)
age =   '75plus'



### setup Python
# import necessary libraries
import  pymc    as mc
import  numpy   as np
import  pylab   as pl
import  pysal
import  os
from    scipy               import sparse
from    scipy.interpolate   import splrep, splev

# setup directory info
project =   'USCOD'
proj_dir =  'D:/Projects/' + project +'/' if (os.environ['OS'] == 'Windows_NT') else '/shared/projects/' + project + '/'



### setup the data
# load in the csv
data =      pl.csv2rec(proj_dir + 'data/model inputs/state_random_effects_input.csv')
print 'Data loaded'

# keep just the specified age and sex
data =      data[(data.sex == sex) & (data.age_group == age)]

# remove any instances of population zero, which might blow things up due to having offsets of negative infinity
data =      data[data.pop > 0.]



### setup temporal indexing
# set year to start at 0
data =          pl.rec_append_fields(
                    rec =   data, 
                    names = 'year0', 
                    arrs =  np.array(data.year - np.min(data.year))
                )

# make a list of years in the data
years =         np.arange(np.min(data.year0), np.max(data.year0)+1, 1)

# find indices of years
year_indices =  np.array([data.year0 == y for y in years])

# make a list of which years to sample the random walks at
knot_spacing =  5
syears =        np.arange(np.min(data.year0), np.max(data.year0)+knot_spacing, knot_spacing)

# make a diagonal matrix for computing the cumulative sum of sample years
syear_cumsum =  np.zeros((len(syears), len(syears)))
for i in range(len(syears)):
    for j in range(len(syears)):
        if i >= j:
            syear_cumsum[i,j] = 1
print 'Finished year indices'

### make lists/indices by state
# list of states
state_names =   np.unique(data.statefips)
state_names.sort()

# make states numeric/sequential in data
data =          pl.rec_append_fields(
                    rec =   data, 
                    names = 'state', 
                    arrs =  np.array([i * (data.statefips == s) for i, s in enumerate(state_names)]).sum(axis=0)
                )
states =        np.arange(len(state_names))

# indices of observations for each state
state_indices = np.array([data.state == s for s in states])
state_indices_sp =  sparse.csr_matrix(state_indices).T

# list of state/year pairs
state_years =   [(s, y) for s in states for y in years]
state_syears =  [(s, y) for s in states for y in syears]

# list of all RW indices for a state
syears_by_state =   []
i = 0
for s in states:
    syears_by_state.append([])
    for y in syears:
        syears_by_state[s].append(i)
        i += 1
years_by_state =   []
i = 0
for s in states:
    years_by_state.append([])
    for y in years:
        years_by_state[s].append(i)
        i += 1

# make state-year variable
data =          pl.rec_append_fields(
                    rec =   data, 
                    names = 'state_year', 
                    arrs =  np.array([i * (data.state == sy[0]) * (data.year0 == sy[1]) for i, sy in enumerate(state_years)]).sum(axis=0)
                )

# product of state and year (summing matrix for drift)
year_by_state =         state_indices * data.year0
year_by_state_sp =      sparse.csr_matrix(year_by_state).T

# indices by state-year (for applying the interpolated random walk)
state_year_indices =    np.array([state_indices[s] & year_indices[y] for s, y in state_years])
state_year_indices_sp = sparse.csr_matrix(state_year_indices).T
print 'Finished state indices'



### make lists/indices by cause
# list of causes
cause_names =   np.unique(data.underlying)
cause_names.sort()

# make causes numeric/sequential in data
data =          pl.rec_append_fields(
                    rec =   data, 
                    names = 'cause', 
                    arrs =  np.array([i * (data.underlying == c) for i, c in enumerate(cause_names)]).sum(axis=0)
                )
causes =        np.arange(len(cause_names))

# indices of observations for each cause
cause_indices = np.array([data.cause == c for c in causes])
cause_indices_sp =  sparse.csr_matrix(cause_indices).T

# list of cause/year pairs
cause_years =   [(c, y) for c in causes for y in years]
cause_syears =  [(c, y) for c in causes for y in syears]

# list of all RW indices for a cause
syears_by_cause =   []
i = 0
for c in causes:
    syears_by_cause.append([])
    for y in syears:
        syears_by_cause[c].append(i)
        i += 1
years_by_cause =   []
i = 0
for c in causes:
    years_by_cause.append([])
    for y in years:
        years_by_cause[c].append(i)
        i += 1

# make cause-year variable
data =          pl.rec_append_fields(
                    rec =   data, 
                    names = 'cause_year', 
                    arrs =  np.array([i * (data.cause == cy[0]) * (data.year0 == cy[1]) for i, cy in enumerate(cause_years)]).sum(axis=0)
                )

# product of cause and year (summing matrix for drift)
year_by_cause =         cause_indices * data.year0
year_by_cause_sp =      sparse.csr_matrix(year_by_cause).T

# indices by cause-year (for applying the interpolated random walk)
cause_year_indices =    np.array([cause_indices[c] & year_indices[y] for c, y in cause_years])
cause_year_indices_sp = sparse.csr_matrix(cause_year_indices).T

# map cause year to cause (because we have separate hyperpriors on u[c,t] by c)
cause_syear_map =       np.array([[cy[0] == c for c in causes] for cy in cause_syears])
print 'Finished cause indices'



### make indices for the interaction of cause and state
# list of state-cause pairs
state_causes =          [(s, c) for s in states for c in causes]

# indices by state-cause (for state-cause intercepts)
state_cause_indices =   np.array([state_indices[s] & cause_indices[c] for s, c in state_causes])
state_cause_indices_sp =sparse.csr_matrix(state_cause_indices).T



### find geographic boundaries
# use the 'queen' boundary counting method (ie include both shared borders and vertices)
bb =                pysal.queen_from_shapefile(proj_dir + 'data/geo/raw/NOAA/s_01ja11.shp', 'Fips')
b, bname =          pysal.weights.insert_diagonal(bb, np.max([np.sum(bb.full()[0], axis=0), np.ones(len(bb.full()[1]))], axis=0.)).full()

# put the boundary matrix in the same order as USCOD has the states setup
neighbor_states =  np.zeros((len(states), len(states)))
for i1,s1 in enumerate(state_names):
    for i2,s2 in enumerate(state_names):
        neighbor_states[i1, i2] =  b[bname.index('%02d' % s1), bname.index('%02d' % s2)]

# instead of 1s, have weights
# diagonal is .5 (unless there are no neighbors), off diagonals are .5/(num neighbors) for neighbors, 0 for non-neighbors
neighbor_states =  (neighbor_states / np.sum(neighbor_states, axis=0)).T

# neighbording state for smoothing the intercepts
intercept_smoothing_matrix =    neighbor_states[data.state].T
intercept_smoothing_sp =        sparse.csr_matrix(intercept_smoothing_matrix).T

# smoothing matrix for drift
drift_smoothing_matrix =        intercept_smoothing_matrix * data.year0
drift_smoothing_sp =            sparse.csr_matrix(drift_smoothing_matrix).T

# smoothing matrix for interactions
interaction_smoothing_matrix =  np.array([intercept_smoothing_matrix[s] * cause_indices[c] for s, c in state_causes])
interaction_smoothing_sp =      sparse.csr_matrix(interaction_smoothing_matrix).T
print 'Finished spatial smoothing indices'



### hyperpriors
# non-informative priors on both mu and sigma for each set of random effects
# B[s]
sigma_b_s = mc.Uniform(
                name =  'sigma_b_s',
                lower = 0.,
                upper = 1e2,
                value = 1.)

# B[c]
sigma_b_c = mc.Uniform(
                name =  'sigma_b_c',
                lower = 0.,
                upper = 1e2,
                value = 1.)

# B[s,c]
sigma_b_sc =mc.Uniform(
                name =  'sigma_b_sc',
                lower = 0.,
                upper = 1e2,
                value = 1.)

# d[s]
sigma_d_s =  mc.Uniform(
                name =  'sigma_d_s',
                lower = 0.,
                upper = 1e2,
                value = 1.)

# d[c]
sigma_d_c = mc.Uniform(
                name =  'sigma_d_c',
                lower = 0.,
                upper = 1e2,
                value = 1.)

# u[s,t]
sigma_u_s = mc.Uniform(
                name =  'sigma_u_s',
                lower = 0.,
                upper = 1e2,
                value = 1.)

# u[c,t]
sigma_u_c = mc.Uniform(
                name =  'sigma_u_c',
                lower = 0.,
                upper = 1e2,
                value = np.ones(len(causes)))
print 'Created hyperpriors'



### model parameters
# alpha
alpha =     mc.Normal(
                name = 'alpha',
                mu =    0.,
                tau =   1e-4,
                value = 0.)

# B[s]
B_s =       mc.Normal(
                name = 'B_s',
                mu =    0.,
                tau =   sigma_b_s**-2,
                value = np.zeros(len(states)))

# B[c]
B_c =       mc.Normal(
                name = 'B_c',
                mu =    0.,
                tau =   sigma_b_c**-2,
                value = np.zeros(len(causes)))

# B[s,c]
B_sc =      [mc.Normal(
                name = 'B_sc_%d' % c,
                mu =    0.,
                tau =   sigma_b_sc**-2,
                value = np.zeros(len(states)))
            for c in causes]

# d[s]
d_s =       mc.Normal(
                name =  'd_s',
                mu =    0.,
                tau =   sigma_d_s**-2,
                value = np.zeros(len(states)))

# d[c]
d_c =       mc.Normal(
                name =  'd_c',
                mu =    0.,
                tau =   sigma_d_c**-2,
                value = np.zeros(len(causes)))

# u[s,t]
u_s =       mc.Normal(
                name =  'u_s',
                mu =    0.,
                tau =   sigma_u_s**-2,
                value = np.zeros(len(state_syears)))

# u[c,t]
u_c =       mc.Normal(
                name =  'u_c',
                mu =    0.,
                tau =   np.dot(cause_syear_map, sigma_u_c**-2).astype('float'),
                value = np.zeros(len(cause_syears)))
print 'Created stochastic parameters'


                    
### prediction
# random intercept by state
@mc.deterministic
def intercept_s(B_s=B_s):
    return  intercept_smoothing_sp.dot(B_s)

# random intercept by cause
@mc.deterministic
def intercept_c(B_c=B_c):
    return  cause_indices_sp.dot(B_c)

# random intercept by state/cause interaction
@mc.deterministic
def intercept_sc(B_sc=B_sc):
    return  state_cause_indices_sp.dot(np.concatenate(B_sc))
print 'Created intercepts'

# cumulative effect of state drift
@mc.deterministic
def drift_s(d_s=d_s):
    return  year_by_state_sp.dot(d_s)

# cumulative effect of cause drift
@mc.deterministic
def drift_c(d_c=d_c):
    return  year_by_cause_sp.dot(d_c)
print 'Created drifts'

# cumulative sum of state random walk
@mc.deterministic
def rw_s(u_s=u_s):
    u_s_interp =    np.zeros(len(state_years))
    for s in states:
        u_s_interp[years_by_state[s]] = splev(years, splrep(syears, np.dot(syear_cumsum, u_s[syears_by_state[s]])))
    return  state_year_indices_sp.dot(u_s_interp)

# cumulative sum of cause random walk
@mc.deterministic
def rw_c(u_c=u_c):
    u_c_interp =    np.zeros(len(cause_years))
    for c in causes:
        u_c_interp[years_by_cause[c]] = splev(years, splrep(syears, np.dot(syear_cumsum, u_c[syears_by_cause[c]])))
    return  cause_year_indices_sp.dot(u_c_interp)
print 'Created random walks'

# exposure (population)
exposure = np.log(data.pop)
print 'Created exposure'

# final prediction
# y[s,c,t=n]  ~ exp(alpha + gamma*n + exposure + B[s] + psi*avg(B[neighbors[s]]) + B[c] + B[s,c] + eta[c]*avg(B[neighbors[s],c]) + d[s]*n + d[c]*n + sum(u[s,t=0:n]) + sum(u[c,t=0:n]))
@mc.deterministic
def estimate(intercept_s=intercept_s, intercept_c=intercept_c, intercept_sc=intercept_sc, alpha=alpha, drift_s=drift_s, drift_c=drift_c, rw_s=rw_s, rw_c=rw_c):
    return  np.exp(intercept_s + intercept_c + intercept_sc + alpha + drift_s + drift_c + rw_s + rw_c + exposure)
print 'Created estimate'

# poisson likelihood
@mc.observed
def data_likelihood(value=data.deaths, estimate=estimate):
    return mc.poisson_like(value, estimate)
print 'Created likelihood'


    
### setup MCMC
# compile variables into a model
model_vars =    [[sigma_b_s, sigma_b_c, sigma_b_sc, sigma_u_s, sigma_u_c, sigma_d_s, sigma_d_c],
                [B_s, B_c, B_sc, alpha, u_s, u_c, d_s, d_c],
                [intercept_s, intercept_c, intercept_sc, drift_s, drift_c, rw_s, rw_c, exposure, estimate],
                [data_likelihood]]
model =         mc.MCMC(model_vars, db='ram')
print 'Compiled model'



# set step method to adaptive metropolis
for s in model.stochastics:
    model.use_step_method(mc.AdaptiveMetropolis, s)
print 'Assigned step methods'


### fit the model
# use MAP iteratively on alpha, then betas, then drifts, to find reasonable starting values for the chains
mc.MAP([alpha, data_likelihood]).fit(method='fmin_powell', verbose=1)
print 'Mapped alpha'
mc.MAP([B_s, data_likelihood]).fit(method='fmin_powell', verbose=1)
mc.MAP([B_c, data_likelihood]).fit(method='fmin_powell', verbose=1)
print 'Mapped intercepts'
for c in causes:
    mc.MAP([B_sc[c], data_likelihood]).fit(method='fmin_powell', verbose=1)
print 'Mapped interactions'
mc.MAP([d_s, d_c, data_likelihood]).fit(method='fmin_powell', verbose=1)
print 'Mapped drifts'

# draw some samples
print 'Beginning sampling'
#model.sample(iter=200000, burn=50000, thin=150, verbose=True)
model.sample(iter=70000, burn=50000, thin=200, verbose=True)
#model.sample(100)


# percentile functions
def percentile(a, q, axis=None, out=None, overwrite_input=False):
    a = np.asarray(a)
    if q == 0:
        return a.min(axis=axis, out=out)
    elif q == 100:
        return a.max(axis=axis, out=out)
    if overwrite_input:
        if axis is None:
            sorted = a.ravel()
            sorted.sort()
        else:
            a.sort(axis=axis)
            sorted = a
    else:
        sorted = np.sort(a, axis=axis)
    if axis is None:
        axis = 0
    return _compute_qth_percentile(sorted, q, axis, out)
def _compute_qth_percentile(sorted, q, axis, out):
    if not np.isscalar(q):
        p = [_compute_qth_percentile(sorted, qi, axis, None)
             for qi in q]
        if out is not None:
            out.flat = p
        return p
    q = q / 100.0
    if (q < 0) or (q > 1):
        raise ValueError, "percentile must be either in the range [0,100]"
    indexer = [slice(None)] * sorted.ndim
    Nx = sorted.shape[axis]
    index = q*(Nx-1)
    i = int(index)
    if i == index:
        indexer[axis] = slice(i, i+1)
        weights = np.array(1)
        sumval = 1.0
    else:
        indexer[axis] = slice(i, i+2)
        j = i + 1
        weights = np.array([(j - index), (index - i)],float)
        wshape = [1]*sorted.ndim
        wshape[axis] = 2
        weights.shape = wshape
        sumval = weights.sum()
    return np.add.reduce(sorted[indexer]*weights, axis=axis, out=out)/sumval



# save basic estimates
model_estimates =   model.trace('estimate')[:]
mean_estimate =     model_estimates.mean(axis=0)
lower_estimate =    percentile(model_estimates, 2.5, axis=0)
upper_estimate =    percentile(model_estimates, 97.5, axis=0)
output =            pl.rec_append_fields(  rec =   data, 
                        names = ['mean', 'lower', 'upper'], 
                        arrs =  [mean_estimate, lower_estimate, upper_estimate])
pl.rec2csv(output, proj_dir + 'outputs/model results/spatial smoothing/spatial_intercept_' + str(sex) + '_' + age + '.csv')

# save draws
draws =     pl.rec_append_fields(
                    rec =   data,
                    names = ['draw_' + str(i+1) for i in range(100)],
                    arrs =  [model.trace('estimate')[i] for i in range(100)])
pl.rec2csv(draws, proj_dir + 'outputs/model results/spatial smoothing/spatial_intercept_draws_' + str(sex) + '_' + age + '.csv')
