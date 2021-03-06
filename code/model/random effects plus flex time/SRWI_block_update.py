'''
Author:		Kyle Foreman
Created:	10 February 2012
Updated:	16 February 2012
Purpose:	add block update options to flexible time model
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


    y[s,c,t=n]  ~ exp(B0[s] + B0[c] + B0[s,c] + alpha + sum(u[s,t=0:n]) + sum(u[c,t=0:n]) + n*d[s] + n*d[c] + exposure)
        
        B0[s]   ~ N(mu_b_s, 1/sigma_b_s^2)
                    random intercept by state
        B0[c]   ~ N(mu_b_c, 1/sigma_b_c^2)
                    random intercept by cause
        B0[s,c] ~ N(mu_b_sc, 1/sigma_b_sc^2)
                    random intercept by cause/state interaction
        alpha   ~ N(0, 1e-4)
                    roughly the average log mortality rate
        u[s,t]  ~ N(0, 1/sigma_u_s^2)
                    random walk in time by state
                    sampled at 5 years intervals then interpolated via cubic spline
        u[c,t]  ~ N(0, 1/sigma_u_c[c]^2)
                    random walk in time by cause
                    sampled at 5 years intervals then interpolated via cubic spline
        d[s]    ~ N(mu_d_s, 1/sigma_d_s^2)
                    temporal drift by state (ie random slope)
        d[c]    ~ N(mu_d_c, 1/sigma_d_c^2)
                    temporal drift by cause (ie random slope)
        exposure: ln(pop[s,c,t])


    hyperpriors
        
        B0[s]   : random intercept by state
            mu_b_s      ~ N(0, 1e-4)
            sigma_b_s   ~ U(0, 1e2)
        
        B0[c]   : random intercept by cause
            mu_b_c      ~ N(0, 1e-4)
            sigma_b_c   ~ U(0, 1e2)
        
        B0[s,c] : random intercept by state/cause interaction
            mu_b_sc     ~ N(0, 1e-4)
            sigma_b_sc  ~ U(0, 1e2)
            
        u[s,t]  : random walk by state
            sigma_u_s   ~ U(0, 1e2)
        
        u[c,t]  : random walk by cause
            sigma_u_c[c]~ U(0, 1e2)
            # note: may want to put a distribution on sigma_cu instead
        
        d[s]    : temporal drift by state
            mu_d_s      ~ N(0, 1e-4)
            sigma_d_s   ~ U(0, 1e2)
        
        d[c]    : temporal drift by cause
            mu_d_c      ~ N(0, 1e-4)
            sigma_d_c   ~ U(0, 1e2) 
'''

### setup Python
# import necessary libraries
import  pymc    as mc
import  numpy   as np
import  pylab   as pl
import  os
from    scipy.interpolate   import splrep, splev

# setup directory info
project =   'USCOD'
proj_dir =  'D:/Projects/' + project +'/' if (os.environ['OS'] == 'Windows_NT') else '/shared/projects/' + project + '/'



### setup the data
# load in the csv
data =      pl.csv2rec(proj_dir + 'data/model inputs/state_random_effects_input.csv')
print 'Data loaded'

# keep just males aged 60-74 for now
data =      data[(data.sex == 1) & (data.age_group == '60to74')]

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
knot_spacing =  5.
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

# indices by state-year (for applying the interpolated random walk)
state_year_indices =    np.array([state_indices[s] & year_indices[y] for s, y in state_years])
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

# indices by cause-year (for applying the interpolated random walk)
cause_year_indices =    np.array([cause_indices[c] & year_indices[y] for c, y in cause_years])

# map cause year to cause (because we have separate hyperpriors on u[c,t] by c)
cause_syear_map =       np.array([[cy[0] == c for c in causes] for cy in cause_syears])
print 'Finished cause indices'



### make indices for the interaction of cause and state
# list of state-cause pairs
state_causes =          [(s, c) for s in states for c in causes]

# indices by state-cause (for state-cause intercepts)
state_cause_indices =   np.array([state_indices[s] & cause_indices[c] for s, c in state_causes])



### hyperpriors
# non-informative priors on both mu and sigma for each set of random effects
# B0[s]
mu_b_s =    mc.Normal(
                name =  'mu_b_s',
                mu =    0.0, 
                tau =   1.0e-4,
                value = 0.0)
sigma_b_s = mc.Uniform(
                name =  'sigma_b_s',
                lower = 0.0,
                upper = 1.0e2,
                value = 1.0)

# B0[c]
mu_b_c =    mc.Normal(
                name =  'mu_b_c',
                mu =    0.0, 
                tau =   1.0e-4,
                value = 0.0)
sigma_b_c = mc.Uniform(
                name =  'sigma_b_c',
                lower = 0.0,
                upper = 1.0e2,
                value = 1.0)

# B0[s,c]
mu_b_sc =   mc.Normal(
                name =  'mu_b_sc',
                mu =    0.0, 
                tau =   1.0e-4,
                value = 0.0)
sigma_b_sc =mc.Uniform(
                name =  'sigma_b_sc',
                lower = 0.0,
                upper = 1.0e2,
                value = 1.0)

# u[s,t]
sigma_u_s = mc.Uniform(
                name =  'sigma_u_s',
                lower = 0.0,
                upper = 1.0e2,
                value = 1.0)

# u[c,t]
sigma_u_c = mc.Uniform(
                name =  'sigma_u_c',
                lower = 0.0,
                upper = 1.0e2,
                value = np.ones(len(causes)))

# d[s]
mu_d_s =    mc.Normal(
                name =  'mu_d_s',
                mu =    0.0, 
                tau =   1.0e-4,
                value = 0.0)
sigma_d_s =  mc.Uniform(
                name =  'sigma_d_s',
                lower = 0.0,
                upper = 1.0e2,
                value = 1.0)

# d[c]
mu_d_c =    mc.Normal(
                name =  'mu_d_c',
                mu =    0.0, 
                tau =   1.0e-4,
                value = 0.0)
sigma_d_c = mc.Uniform(
                name =  'sigma_d_c',
                lower = 0.0,
                upper = 1.0e2,
                value = 1.0)
print 'Created hyperpriors'



### setup block updates
# B0[s]
num_B0_s_blocks =   5
B0_s_blocks =       [np.arange(i*np.ceil(len(states) / np.float(num_B0_s_blocks)), (i+1)*np.ceil(len(states) / np.float(num_B0_s_blocks))) for i in range(num_B0_s_blocks)]
B0_s_blocks[len(B0_s_blocks)-1] = np.arange(i*np.ceil(len(states) / np.float(num_B0_s_blocks)), len(states))

# B0[c]
num_B0_c_blocks =   3
B0_c_blocks =       [np.arange(i*np.ceil(len(causes) / np.float(num_B0_c_blocks)), (i+1)*np.ceil(len(causes) / np.float(num_B0_c_blocks))) for i in range(num_B0_c_blocks)]
B0_c_blocks[len(B0_c_blocks)-1] = np.arange(i*np.ceil(len(causes) / np.float(num_B0_c_blocks)), len(causes))

# B0[s,c]
num_B0_sc_blocks =  len(states)
B0_sc_blocks =      [np.arange(i*len(causes), (i+1)*len(causes)) for i in range(len(states))]

# d[s]
num_d_s_blocks =    5
d_s_blocks =        [np.arange(i*np.ceil(len(states) / np.float(num_d_s_blocks)), (i+1)*np.ceil(len(states) / np.float(num_d_s_blocks))) for i in range(num_d_s_blocks)]
d_s_blocks[len(d_s_blocks)-1] = np.arange(i*np.ceil(len(states) / np.float(num_d_s_blocks)), len(states))

# d[c]
num_d_c_blocks =    3
d_c_blocks =        [np.arange(i*np.ceil(len(causes) / np.float(num_d_c_blocks)), (i+1)*np.ceil(len(causes) / np.float(num_d_c_blocks))) for i in range(num_d_c_blocks)]
d_c_blocks[len(d_c_blocks)-1] = np.arange(i*np.ceil(len(causes) / np.float(num_d_c_blocks)), len(causes))
'''
# u[s]
num_u_s_blocks =    10
u_s_blocks =        [np.arange(i*np.ceil(len(state_syears) / np.float(num_u_s_blocks)), (i+1)*np.ceil(len(state_syears) / np.float(num_u_s_blocks))) for i in range(num_u_s_blocks)]
u_s_blocks[len(u_s_blocks)-1] = np.arange(i*np.ceil(len(state_syears) / np.float(num_u_s_blocks)), len(state_syears))

# u[c]
num_u_c_blocks =    10
u_c_blocks =        [np.arange(i*np.ceil(len(cause_syears) / np.float(num_u_c_blocks)), (i+1)*np.ceil(len(cause_syears) / np.float(num_u_c_blocks))) for i in range(num_u_c_blocks)]
u_c_blocks[len(u_c_blocks)-1] = np.arange(i*np.ceil(len(cause_syears) / np.float(num_u_c_blocks)), len(cause_syears))
'''
print 'Finished blocking updates'



### model parameters
# B0[s]
B0_s =      [mc.Normal(
                name = 'B0_s_%d' % i,
                mu =    mu_b_s,
                tau =   sigma_b_s**-2,
                value = np.zeros(len(B0_s_blocks[i])))
            for i in range(num_B0_s_blocks)]

# B0[c]
B0_c =      [mc.Normal(
                name = 'B0_c_%d' % i,
                mu =    mu_b_c,
                tau =   sigma_b_c**-2,
                value = np.zeros(len(B0_c_blocks[i])))
            for i in range(num_B0_c_blocks)]

# B0[s,c]
B0_sc =     [mc.Normal(
                name = 'B0_sc_%d' % i,
                mu =    mu_b_sc,
                tau =   sigma_b_sc**-2,
                value = np.zeros(len(B0_sc_blocks[i])))
            for i in range(num_B0_sc_blocks)]
                
# alpha
alpha =     mc.Normal(
                name = 'alpha',
                mu =    0.0,
                tau =   1.0e-4,
                value = 0.0)

# d[s]
d_s =       [mc.Normal(
                name =  'd_s_%d' % i,
                mu =    mu_d_s,
                tau =   sigma_d_s**-2,
                value = np.zeros(len(d_s_blocks[i])))
            for i in range(num_d_s_blocks)]

# d[c]
d_c =       [mc.Normal(
                name =  'd_c_%d' % i,
                mu =    mu_d_c,
                tau =   sigma_d_c**-2,
                value = np.zeros(len(d_c_blocks[i])))
            for i in range(num_d_c_blocks)]

# u[s,t]
'''
u_s =       [mc.Normal(
                name =  'u_s_%d' % i,
                mu =    0.0,
                tau =   sigma_u_s**-2,
                value = np.zeros(len(u_s_blocks[i])))
            for i in range(num_u_s_blocks)]
'''
u_s =       [mc.Normal(
                name =  'u_s_%d' % i,
                mu =    0.0,
                tau =   sigma_u_s**-2,
                value = np.zeros(len(syears)))
            for i in range(len(states))]

# u[c,t]
u_c =       [mc.Normal(
                name =  'u_c_%d' % i,
                mu =    0.0,
                tau =   sigma_u_c[i]**-2,
                value = np.zeros(len(syears)))
            for i in range(len(causes))]
print 'Created stochastic parameters'


                    
### prediction
# random intercept by state
@mc.deterministic
def intercept_s(B0_s=B0_s):
    return np.dot(np.concatenate(B0_s), state_indices)

# random intercept by cause
@mc.deterministic
def intercept_c(B0_c=B0_c):
    return np.dot(np.concatenate(B0_c), cause_indices)

# random intercept by state/cause interaction
@mc.deterministic
def intercept_sc(B0_sc=B0_sc):
    return np.dot(np.concatenate(B0_sc), state_cause_indices)
print 'Created intercepts'

# cumulative effect of state drift
@mc.deterministic
def drift_s(d_s=d_s):
    return np.dot(np.concatenate(d_s), year_by_state)

# cumulative effect of cause drift
@mc.deterministic
def drift_c(d_c=d_c):
    return np.dot(np.concatenate(d_c), year_by_cause)
print 'Created drifts'

# cumulative sum of state random walk
@mc.deterministic
def rw_s(u_s=u_s):
    u_s_flat =      np.concatenate(u_s)
    u_s_interp =    np.zeros(len(state_years))
    for s in states:
        u_s_interp[years_by_state[s]] = splev(years, splrep(syears, np.dot(syear_cumsum, u_s_flat[syears_by_state[s]])))
    return np.dot(u_s_interp, state_year_indices)

# cumulative sum of cause random walk
@mc.deterministic
def rw_c(u_c=u_c):
    u_c_flat =      np.concatenate(u_c)
    u_c_interp =    np.zeros(len(cause_years))
    for c in causes:
        u_c_interp[years_by_cause[c]] = splev(years, splrep(syears, np.dot(syear_cumsum, u_c_flat[syears_by_cause[c]])))
    return np.dot(u_c_interp, cause_year_indices)
print 'Created random walks'

# exposure (population)
exposure = np.log(data.pop)
print 'Created exposure'

# final prediction
# y[s,c,t=n]  ~ exp(B0[s] + B0[c] + B0[s,c] + alpha + sum(u[s,t=0:n]) + sum(u[c,t=0:n]) + n*d[s] + n*d[c] + exposure)
@mc.deterministic
def estimate(intercept_s=intercept_s, intercept_c=intercept_c, intercept_sc=intercept_sc, alpha=alpha, drift_s=drift_s, drift_c=drift_c, rw_s=rw_s, rw_c=rw_c):
    return np.exp(intercept_s + intercept_c + intercept_sc + alpha + drift_s + drift_c + rw_s + rw_c + exposure)
print 'Created estimate'

# poisson likelihood
@mc.observed
def data_likelihood(value=data.deaths, estimate=estimate):
    return mc.poisson_like(value, estimate)
print 'Created likelihood'


    
### setup MCMC
# compile variables into a model
model_vars =    [[mu_b_s, sigma_b_s, mu_b_c, sigma_b_c, mu_b_sc, sigma_b_sc, sigma_u_s, sigma_u_c, mu_d_s, sigma_d_s, mu_d_c, sigma_d_c],
                [B0_s, B0_c, B0_sc, alpha, u_s, u_c, d_s, d_c],
                [intercept_s, intercept_c, intercept_sc, drift_s, drift_c, rw_s, rw_c, exposure, estimate],
                [data_likelihood]]
model =         mc.MCMC(model_vars, db='ram')
print 'Compiled model'



# set step method to adaptive metropolis
for s in model.stochastics:
    #model.use_step_method(mc.AdaptiveMetropolis, s, interval=100)
    model.use_step_method(mc.Metropolis, s)
print 'Assigned step methods'


### fit the model
# use MAP iteratively on alpha, then betas, then drifts, to find reasonable starting values for the chains
mc.MAP([alpha, data_likelihood]).fit(method='fmin_powell', verbose=1)
print 'Mapped alpha'
mc.MAP([B0_s, B0_c, data_likelihood]).fit(method='fmin_powell', verbose=1)
print 'Mapped intercepts'
mc.MAP([B0_sc, data_likelihood]).fit(method='fmin_powell', verbose=1)
print 'Mapped interactions'
mc.MAP([d_s, d_c, data_likelihood]).fit(method='fmin_powell', verbose=1)
print 'Mapped drifts'

# draw some samples
print 'Beginning sampling'
#model.sample(iter=200000, burn=50000, thin=150, verbose=True)
model.sample(iter=50000, burn=20000, thin=30, verbose=True)
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
pl.rec2csv(output, proj_dir + 'outputs/model results/random effects plus flex time/srw_plus_interaction_results.csv')


'''
### plot diagnostics
# setup plotting
#import matplotlib.pyplot as pp
#pp.switch_backend('acc')
plot_me = [mu_si, mu_ss, mu_ci, mu_cs, sigma_si, sigma_ss, sigma_ci, sigma_cs, state_intercepts, state_slopes, cause_intercepts, cause_slopes]

# plot traces
os.chdir(proj_dir + '/outputs/model results/simple random effects by state/mcmc plots/traces/')
for p in plot_me:
    mc.Matplot.plot(p, suffix='_trace')
    if len(p.shape) == 0:
        plt.close()
    else:
        for i in range(np.int(np.ceil(p.shape[0] / 4.))):
            plt.close()

# plot autocorrelation
os.chdir(proj_dir + '/outputs/model results/simple random effects by state/mcmc plots/autocorrelation/')
for p in plot_me:
    mc.Matplot.autocorrelation(p, suffix='_autocorrelation')
    if len(p.shape) == 0:
        plt.close()
    else:
        for i in range(np.int(np.ceil(p.shape[0] / 4.))):
            plt.close()

# plot geweke
os.chdir(proj_dir + '/outputs/model results/simple random effects by state/mcmc plots/geweke/')
for p in plot_me:
    scores = mc.geweke(p, intervals=20)
    mc.Matplot.geweke_plot(scores, p.__name__, suffix='_geweke')
    if len(p.shape) == 0:
        plt.close()
    else:
        for i in range(np.int(np.ceil(p.shape[0] / 4.))):
            plt.close()
'''

'''
# plot predictions
pp = PdfPages(proj_dir + 'outputs/model results/epi transition by state/predictions.pdf')
for g in g_list:
    d =     output[output.state == g]
    fig =   plt.figure()
    axis_num = 0
    for a in ages:
        dd =    d[d.age_group == a]
        axis_num += 1
        ax =    plt.subplot(2, 3, axis_num)
        plt.plot(dd.year, dd.deaths, 'wo')
        if axis_num == 2:
            ax.set_title(state_lookup[g] + '\n%s' % a)
        else:
            ax.set_title(a)
        for tick in ax.xaxis.get_major_ticks():
            tick.label.set_fontsize(8) 
        plt.fill_between(dd.year, dd.lower, dd.upper, color='#B1DCFE')
        plt.plot(dd.year, dd['mean'], 'b-', color='#315B7E')
    pp.savefig()
    plt.close()
pp.close()
'''




'''
# return mean, lower, upper for a parameter
def find_param_stats(param):
    m = param.trace().mean(axis=0)
    l = percentile(param.trace(), 2.5, axis=0)
    u = percentile(param.trace(), 97.5, axis=0)
    return np.rec.fromarrays([m, l, u], names='mean_val,lower_val,upper_val')
# return error in the format desired for 'errorbar' matplotlib plots
def find_param_error(param):
    s = find_param_stats(param)
    return s.mean_val, np.array([s.mean_val - s.lower_val, s.upper_val - s.mean_val])


### plot parameter values
# plot state intercepts
v, e = find_param_error(state_intercepts)
plt.errorbar(v, range(len(v)), e, fmt='bo')

'''
