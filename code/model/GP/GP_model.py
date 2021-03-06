'''
Author:		Kyle Foreman
Created:	28 Mar 2012
Updated:	28 Mar 2012
Purpose:	fit smoothed RW with interactions model, adding in spatial smoothing (GP)
'''

### model specification
'''
    deaths_{s,c,t}   ~ \Poisson(y_{s,c,t})
        
        s   : state (plus DC)
                0:50
        c   : cause of death
                0:24
        t   : year
                0:38 (1979:2007)

    
    y_{s,c,t}  ~ \exp(\alpha + \gamma \times t + exposure + SI_{s} + CI_{c} + XI_{s,c} + SS_{s} \times t + CS_{c} \times t + \sum_{n=0}^t(SRW_{s,n}) + \sum_{n=0}^t(CRW_{c,n}))

        
        average log mortality rate (roughly...)
            \alpha  ~ \Normal(0, 1e-4)
        
        annual change in average log mortality rate
            \gamma  ~ \Normal(0, 1e-4)

        exposure
            \ln(pop_{s,c,t})
            
        cause random intercept
            CI_{c}  ~ \Normal(0, 1/sigma_{CI}^2)
        
        spatial random intercept (GP smoothing)
            SI_{s}  ~ \MVN(0, SIC)
            SIC :   Matern covariance with amplitude of sigma_{SI} and scale of rho_{SI}
            constraint: \sum_{s}(SI) = 0
        
        cause/spatial interaction intercept (GP smoothing over space within cause)
            XI_{s,c}~ \MVN(0, XIC)
            XIC :   Matern covariance with amplitude of sigma_{XI} and scale of rho_{XI}
            constraint: \sum_{s}(XI_{c}) = 0
     
        temporal drift by state (ie random slope), (GP smoothing)
            SS_{s}  ~ \MVN(0, SSC)
            SSC :   Matern covariance with amplitude of sigma_{SS} and scale of rho_{SS}
            constraint: \sum_{s}(SS) = 0
     
        temporal drift by cause (ie random slope)
            CS_{c}  ~ \Normal(0, 1/sigma_{CS}^2)
            constraint: \sum_{c}(CS) = 0
            
        random walk in time by state
            SRW_{s,t}   ~ \Normal(0, 1/sigma_{SRW}^2)
            constraint: \sum_{t}(SRW_{s}) = 0
        
        random walk in time by cause
            CRW_{c,t}   ~ \Normal(0, 1/sigma_{CRW, c}^2)
            constraint: \sum_{t}(CRW_{c}) = 0



    hyperpriors
        sigma_{x}       ~ U(0, 1e2) 
        rho_{x}         ~ U(0, 1e5)
'''

### define which model to run
# sex? (1 = Male, 2 = Female)
sex =   1
# age? (Under5, 5to14, 15to29, 30to44, 45to59, 60to74, 75plus)
age =   '60to74'
# model name? (for prefixing output files)
mod_name =  'GP'



### setup Python
# import necessary libraries
import  pymc    as mc
import  numpy   as np
import  pylab   as pl
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
year_cumsum =  np.zeros((len(years), len(years)))
for i in range(len(years)):
    for j in range(len(years)):
        if i >= j:
            year_cumsum[i,j] = 1

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



### find geographic location (based on 2000 US Census's 'population center')
# open the population center dataset
state_centers =     pl.csv2rec(proj_dir + 'data/geo/clean/state_centers.csv')

# turn into an array of long/lat pairs
long_lat =          np.array([[state_centers[state_centers.fips==s].longitude[0], state_centers[state_centers.fips==s].latitude[0]] for s in state_names])



### hyperpriors
# non-informative priors on both mu and sigma for each set of random effects
# Spatial Intercept (GP)
sigma_SI =  mc.Uniform(
                name =  'sigma_SI',
                lower = 0.,
                upper = 1e2,
                value = 1.)
rho_SI =    mc.Uniform(
                name =  'rho_SI',
                lower = 0.,
                upper = 1e5,
                value = 1.)

# Cause Intercept
sigma_CI =  mc.Uniform(
                name =  'sigma_CI',
                lower = 0.,
                upper = 1e2,
                value = 1.)

# Spatial/Cause Interaction (GP over spatial within each cause)
sigma_XI =  mc.Uniform(
                name =  'sigma_XI',
                lower = 0.,
                upper = 1e2,
                value = 1.)
rho_XI =    mc.Uniform(
                name =  'rho_XI',
                lower = 0.,
                upper = 1e5,
                value = 1.)

# Spatial Component - Temporal Drift (GP)
sigma_SS =  mc.Uniform(
                name =  'sigma_SS',
                lower = 0.,
                upper = 1e2,
                value = 1.)
rho_SS =    mc.Uniform(
                name =  'rho_SS',
                lower = 0.,
                upper = 1e5,
                value = 1.)

# Cause - Temporal Drift
sigma_CS =  mc.Uniform(
                name =  'sigma_CS',
                lower = 0.,
                upper = 1e2,
                value = 1.)

# Temporal Random Walk - Spatial Component
sigma_SRW = mc.Uniform(
                name =  'sigma_SRW',
                lower = 0.,
                upper = 1e2,
                value = 1.)

# Temporal Random Walk - Cause (one value per cause)
sigma_CRW = mc.Uniform(
                name =  'sigma_CRW',
                lower = 0.,
                upper = 1e2,
                value = np.ones(len(causes)))
print 'Created hyperpriors'



### mean and covariance functions
# mean function (simply return 0)
def justzero(x):
    return np.zeros(len(x))
M = mc.gp.Mean(justzero)

# state intercept covariance
@mc.deterministic
def SIC(sigma_SI=sigma_SI, rho_SI=rho_SI):
    return mc.gp.Covariance(eval_fun = mc.gp.matern.geo_deg, diff_degree=2., amp=sigma_SI, scale=rho_SI) 
    
# state-cause interaction covariance
@mc.deterministic
def XIC(sigma_XI=sigma_XI, rho_XI=rho_XI):
    return mc.gp.Covariance(eval_fun = mc.gp.matern.geo_deg, diff_degree=2., amp=sigma_XI, scale=rho_XI) 
    
# state drift covariance
@mc.deterministic
def SSC(sigma_SS=sigma_SS, rho_SS=rho_SS):
    return mc.gp.Covariance(eval_fun = mc.gp.matern.geo_deg, diff_degree=2., amp=sigma_SS, scale=rho_SS) 



### model parameters
# alpha
alpha =     mc.Normal(
                name = 'alpha',
                mu =    0.,
                tau =   1e-4,
                value = 0.)

# gamma
gamma =     mc.Normal(
                name = 'gamma',
                mu =    0.,
                tau =   1e-4,
                value = 0.)

# cause intercept
CI =        mc.Normal(
                name = 'CI',
                mu =    0.,
                tau =   sigma_CI**-2,
                value = np.zeros(len(causes)))

# state intercept
SI =        mc.gp.GPSubmodel(
                name =  'SI',
                M =     M,
                C =     SIC,
                mesh =  long_lat)

# state-cause interaction
XI =        [mc.gp.GPSubmodel(
                name =  'XI_%s' % c,
                M =     M,
                C =     XIC,
                mesh =  long_lat)
            for c in causes]

# cause drifts
CS =        mc.Normal(
                name =  'CS',
                mu =    0.,
                tau =   sigma_CS**-2,
                value = np.zeros(len(causes)))

# state slopes
SS =        mc.gp.GPSubmodel(
                name =  'SS',
                M =     M,
                C =     SSC,
                mesh =  long_lat)

# cause random walks
CRW =       [mc.Normal(
                name =  'CRW_%s' % c,
                mu =    0.,
                tau =   sigma_CRW[c],
                value = np.zeros(len(years)))
            for c in causes]

# state random walks
SRW =       [mc.Normal(
                name =  'SRW_%s' % s,
                mu =    0.,
                tau =   sigma_SRW,
                value = np.zeros(len(years)))
            for s in states]
print 'Created stochastic parameters'


                    
### prediction
# random intercept by cause
@mc.deterministic
def CI_pred(CI=CI):
    return  cause_indices_sp.dot(CI)

# random intercept by state
@mc.deterministic
def SI_pred(SI=SI):
    return  state_indices_sp.dot(SI.f_eval)

# random intercept by state/cause interaction
@mc.deterministic
def XI_pred(XI=XI):
    return  state_cause_indices_sp.dot(np.concatenate([c.f_eval for c in XI]))
print 'Created intercepts'



# overall drift (slope)
@mc.deterministic
def gamma_pred(gamma=gamma):
    return  data.year0.dot(gamma)

# cumulative effect of cause drift
@mc.deterministic
def CS_pred(CS=CS):
    return  year_by_cause_sp.dot(CS)

# cumulative effect of state drift
@mc.deterministic
def SS_pred(SS=SS):
    return  year_by_state_sp.dot(SS.f_eval)
print 'Created drifts'



# cumulative sum of cause random walk
@mc.deterministic
def CRW_pred(CRW=CRW):
    return  cause_year_indices_sp.dot(np.concatenate([np.dot(year_cumsum, crw) for crw in CRW]))

# cumulative sum of state random walk
@mc.deterministic
def SRW_pred(SRW=SRW):
    return  state_year_indices_sp.dot(np.concatenate([np.dot(year_cumsum, srw) for srw in SRW]))
print 'Created random walks'



# exposure (population)
exposure =  np.log(data.pop)
print 'Created exposure'



# final prediction
@mc.deterministic
def estimate(alpha=alpha, gamma=gamma_pred, exposure=exposure, CI=CI_pred, SI=SI_pred, XI=XI_pred, CS=CS_pred, SS=SS_pred, CRW=CRW_pred, SRW=SRW_pred):
    return  np.exp(alpha + gamma + exposure + CI + SI + XI + CS + SS + CRW + SRW)
print 'Created estimate'



# poisson likelihood
@mc.observed
def data_likelihood(value=data.deaths, estimate=estimate):
    return mc.poisson_like(value, estimate)
print 'Created likelihood'


    
### setup MCMC
# compile variables into a model
model_vars =    [[sigma_CI, sigma_SI, rho_SI, sigma_XI, rho_XI, sigma_CS, sigma_SS, rho_SS, sigma_CRW, sigma_SRW],
                [alpha, gamma, CI, SI, XI, CS, SS, CRW, SRW],
                [gamma_pred, CI_pred, SI_pred, XI_pred, CS_pred, SS_pred, CRW_pred, SRW_pred, estimate],
                [data_likelihood]]
model =         mc.MCMC(model_vars, db='ram')
print 'Compiled model'



### set step methods
# use GP AM for GPs
for s in [SI, SS] + XI:
    model.use_step_method(mc.AdaptiveMetropolis, s.stochastics)
print 'Assigned step methods'
'''

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
pl.rec2csv(output, proj_dir + 'outputs/model results/spatial smoothing/' + mod_name + '_' + str(sex) + '_' + age + '.csv')

# save draws
draws =     pl.rec_append_fields(
                    rec =   data,
                    names = ['draw_' + str(i+1) for i in range(100)],
                    arrs =  [model.trace('estimate')[i] for i in range(100)])
pl.rec2csv(draws, proj_dir + 'outputs/model results/spatial smoothing/' + mod_name + '_draws_' + str(sex) + '_' + age + '.csv')
'''
