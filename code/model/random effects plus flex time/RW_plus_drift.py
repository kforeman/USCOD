'''
Author:		Kyle Foreman
Created:	8 February 2012
Updated:	8 February 2012
Purpose:	fit a random walk with drift model
'''

### model specification
'''
    deaths[s,c,t]   ~ Poisson(y[s,c,t])

    y[s,c,t=n]  ~ exp(B0[s] + B0[c] + alpha + exposure + sum(u[s,t=0:n]) + sum(u[c,t=0:n]) + n*d[s] + n*d[c])
        
        B0[s]   ~ N(mu_sb, tau_sb)
                    random intercept by state
        B0[c]   ~ N(mu_cb, tau_cb)
                    random intercept by cause
        alpha   ~ N(0, 1e-6)
                    roughly the average log mortality rate
        exposure: ln(pop[s,c,t])
        u[s,t]  ~ N(0, tau_su)
                    random walk in time by state
        u[c,t]  ~ N(0, tau_cu[c])
                    random walk in time by cause
        d[s]    ~ N(mu_sd, tau_sd)
                    temporal drift by state (ie random slope)
        d[c]    ~ N(mu_cd, tau_cd)
                    temporal drift by cause (ie random slope)

    hyperpriors
        
        B0[s]   : random intercept by state
            mu_sb   ~ N(0, 1e-4)
            tau_sb  ~ U(0, 1e2)
        
        B0[c]   : random intercept by cause
            mu_cb   ~ N(0, 1e-4)
            tau_cb  ~ U(0, 1e2)
            
        u[s,t]  : random walk by state
            tau_su  ~ U(0, 1e2)
        
        u[c,t]  : random walk by cause
            tau_cu[c]~U(0, 1e2)
            # note: may want to put a distribution on tau_cu instead
        
        d[s]    : temporal drift by state
            mu_sd   ~ N(0, 1e-4)
            tau_sd  ~ U(0, 1e2)
        
        d[c]    : temporal drift by cause
            mu_cd   ~ N(0, 1e-4)
            tau_cd  ~ U(0, 1e2)
            
'''

### setup Python
# import necessary libraries
import  pymc    as mc
import  numpy   as np
import  pylab   as pl
import  os

# setup directory info
project =   'USCOD'
proj_dir =  'D:/Projects/' + project +'/' if (os.environ['OS'] == 'Windows_NT') else '/shared/projects/' + project + '/'



### setup the data
# load in the csv
data =      pl.csv2rec(proj_dir + 'data/model inputs/state_random_effects_input.csv')

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

# index the data by year
year_indices =  np.array([data.year0 == y for y in years])



### make lists/indices by state
# list of states
states =        dict([(s, i) for i, s in enumerate(np.unique(data.statefips))])

# indices of observations for each state
state_indices = np.array([data.statefips == s for s in states])

# list of state/year pairs
state_years =   dict([(sy, i) for i, sy in enumerate([(s, y) for s in states for y in years])])

# indices of state/year pairs
state_year_indices =    np.array([year_indices[years[y]] & state_indices[states[s]] for s, y in state_years])

# product of state and year (summing matrix for drift)
state_times_year =      state_indices * data.year0



### make lists/indices by cause
# list of causes
causes =        dict([(c, i) for i, c in enumerate(np.unique(data.underlying))])

# indices of observations for each cause
cause_indices = np.array([data.underlying == c for c in causes])

# list of cause/year pairs
cause_years =   dict([(cy, i) for i, cy in enumerate([(c, y) for c in causes for y in years])])

# indices of cause/year pairs
cause_year_indices =    np.array([year_indices[years[y]] & cause_indices[causes[c]] for c, y in cause_years])

# product of cause and year (summing matrix for drift)
cause_times_year =      cause_indices * data.year0



### hyperpriors
# non-informative priors on both mu and sigma for each set of random effects
# state intercept
mu_si =     mc.Normal(
                name =  'mu_si',
                mu =    0.0, 
                tau =   1.0e-4,
                value = 0.0)
sigma_si =  mc.Uniform(
                name =  'sigma_si',
                lower = 0.0,
                upper = 1.0e2,
                value = 1.0)
# state slope
mu_ss =     mc.Normal(
                name =  'mu_ss',
                mu =    0.0, 
                tau =   1.0e-4,
                value = 0.0)
sigma_ss =  mc.Uniform(
                name =  'sigma_ss',
                lower = 0.0,
                upper = 1.0e2,
                value = 1.0)
# state spline
sigma_sp =  mc.Uniform(
                name =  'sigma_sp',
                lower = 0.0,
                upper = 1.0e2,
                value = 1.0)
# cause intercept
mu_ci =     mc.Normal(
                name =  'mu_ci',
                mu =    0.0, 
                tau =   1.0e-4,
                value = 0.0)
sigma_ci =  mc.Uniform(
                name =  'sigma_ci',
                lower = 0.0,
                upper = 1.0e2,
                value = 1.0)
# cause slope
mu_cs =     mc.Normal(
                name =  'mu_cs',
                mu =    0.0, 
                tau =   1.0e-4,
                value = 0.0)
sigma_cs =  mc.Uniform(
                name =  'sigma_cs',
                lower = 0.0,
                upper = 1.0e2,
                value = 1.0)
# cause spline
sigma_cp =  mc.Uniform(
                name =  'sigma_cp',
                lower = 0.0,
                upper = 1.0e2,
                value = 1.0)

                
### random effects
# state intercepts
state_intercepts =  mc.Normal(
                        name = 'state_intercepts',
                        mu =    mu_si,
                        tau =   1.0 / sigma_si**2,
                        value = np.zeros(len(state_list))
                    )
# state slopes
state_slopes =      mc.Normal(
                        name = 'state_slopes',
                        mu =    mu_ss,
                        tau =   1.0 / sigma_ss**2,
                        value = np.zeros(len(state_list))
                    )
# state splines
state_splines =     mc.Normal(
                        name = 'state_splines',
                        mu =    0.,
                        tau =   1.0 / sigma_sp**2,
                        value = np.zeros(len(state_syear_list))
                    )
# cause intercepts
cause_intercepts =  mc.Normal(
                        name = 'cause_intercepts',
                        mu =    mu_ci,
                        tau =   1.0 / sigma_ci**2,
                        value = np.zeros(len(cause_list))
                    )
# cause slopes
cause_slopes =      mc.Normal(
                        name = 'cause_slopes',
                        mu =    mu_cs,
                        tau =   1.0 / sigma_cs**2,
                        value = np.zeros(len(cause_list))
                    )
# cause splines
cause_splines =     mc.Normal(
                        name = 'cause_splines',
                        mu =    0.,
                        tau =   1.0 / sigma_cp**2,
                        value = np.zeros(len(cause_syear_list))
                    )


                    
### prediction
# interpolated state splines
@mc.deterministic
def state_interpolated(state_splines=state_splines, state_year_indices=state_year_indices, state_syear_list=state_syear_list):
    map(spline_interpolation, state_syear_list)

# total of state-level effects
@mc.deterministic
def state_effects(state_intercepts=state_intercepts, state_slopes=state_slopes, state_indices=state_indices, data=data):
    return np.dot(state_intercepts, state_indices) + (np.dot(state_slopes, state_indices) * data.year_std)

# total of cause-level effects
@mc.deterministic
def cause_effects(cause_intercepts=cause_intercepts, cause_slopes=cause_slopes, cause_indices=cause_indices, data=data):
    return np.dot(cause_intercepts, cause_indices) + (np.dot(cause_slopes, cause_indices) * data.year_std)

# exposure (population)
@mc.deterministic
def exposure(data=data):
    return np.log(data.pop)

# final prediction
@mc.deterministic
def estimate(state_effects=state_effects, cause_effects=cause_effects, exposure=exposure):
    # return np.round(np.exp(exposure + state_effects + cause_effects))
    return np.exp(exposure + state_effects + cause_effects)

# poisson likelihood
@mc.observed
def data_likelihood(value=data.deaths, mu=estimate):
    return mc.poisson_like(value, mu)


    
### setup MCMC
# compile variables into a model
model_vars =    [[mu_si, mu_ss, mu_ci, mu_cs, sigma_si, sigma_ss, sigma_ci, sigma_cs],
                [state_intercepts, state_slopes],
                [cause_intercepts, cause_slopes],
                [state_effects, cause_effects, exposure, estimate, data_likelihood]]
model =         mc.MCMC(model_vars, db='ram')

# set step method to adaptive metropolis
for s in model.stochastics:
    model.use_step_method(mc.AdaptiveMetropolis, s, interval=100)

    
### fit the model
# use MAP to find starting values
#mc.MAP(model_vars).fit(method='fmin_powell', verbose=1)
#mc.MAP(model_vars).fit(verbose=1, iterlim=1e3, method='fmin_powell')

# draw some samples
#model.sample(10)
model.sample(iter=200000, burn=100000, thin=100, verbose=1)


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
pl.rec2csv(output, proj_dir + 'outputs/model results/simple random effects by state/pymc_results.csv')



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
