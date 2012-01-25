'''
Author:		Kyle Foreman
Created:	24 Jan 2012
Updated:	24 Jan 2012
Purpose:	fit model with random intercepts and slopes by cause and state
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
data =      data[data.pop > 0]

# center and standardize year
data = pl.rec_append_fields(
            rec =   data, 
            names = 'year_std', 
            arrs =  np.array((data.year - np.mean(data.year)) / np.std(data.year))
       )



### find indices to speed up later insertion of random effects
# list of states
state_list =    dict([(s, i) for i, s in enumerate(np.unique(data.statefips))])

# indices of observations for each state
state_indices = np.array([data.statefips == s for s in state_list])

# list of causes
cause_list =    dict([(c, i) for i, c in enumerate(np.unique(data.underlying))])

# indices of observations for each cause
cause_indices = np.array([data.underlying == c for c in cause_list])



### hyperpriors
# non-informative priors on both mu and sigma for each set of random effects
# state intercept
mu_si =     mc.Normal(
                name =  'mu_si',
                mu =    0.0, 
                tau =   1.0e-6,
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
                tau =   1.0e-6,
                value = 0.0)
sigma_ss =  mc.Uniform(
                name =  'sigma_ss',
                lower = 0.0,
                upper = 1.0e2,
                value = 1.0)
# cause intercept
mu_ci =     mc.Normal(
                name =  'mu_ci',
                mu =    0.0, 
                tau =   1.0e-6,
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
                tau =   1.0e-6,
                value = 0.0)
sigma_cs =  mc.Uniform(
                name =  'sigma_cs',
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


                    
### prediction
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
#model.sample(iter=20000, burn=10000, thin=10, verbose=1)
model.sample(iter=50000, burn=40000, thin=10, verbose=1)






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
