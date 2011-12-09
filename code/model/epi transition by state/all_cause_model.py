'''
Author:		Kyle Foreman
Created:	18 November 2011
Updated:	21 November 2011
Purpose:	fit a total mortality model by state
'''

# import necessary libraries
import  pymc    as mc
import  numpy   as np
import  pylab   as pl
import  os
from    scipy   import interpolate

# setup directory info
project =   'USCOD'
proj_dir =  'D:/Projects/' + project +'/' if (os.environ['OS'] == 'Windows_NT') else '/shared/projects/' + project + '/'

# load in the data
data =      pl.csv2rec(proj_dir + 'data/model inputs/epi_transition_by_state.csv')

# keep just total mortality in males for now
data =      data[(data.cause == 'T') & (data.sex == 1)]

# find age groups, years, and states
ages =          np.unique(data.age_group)
sample_ages =   ages
years =         np.unique(data.year)
sample_years =  np.arange(np.floor(np.min(data.year)/5.)*5., np.ceil(np.max(data.year)/5.)*5.+5., 5.)
states =        np.unique(data.state)
state_names =   pl.csv2rec(proj_dir + 'data/geo/clean/state_names.csv')
state_lookup = {}
for s in state_names:
    state_lookup[s.statefips] = s.name

# index data by state, age, and year
g_list      = dict([(g, i) for i, g in enumerate(states)])
g_indices   = dict([(g, data.state == g) for g in g_list])
t_list      = dict([(t, i) for i, t in enumerate(years)])
t_lookup    = [t_list[data.year[i]] for i in np.arange(len(data))]
t_by_g      = [[t_list[data.year[i]] for i in g_indices[g]] for g in g_list]
a_list      = dict([(a, i) for i, a in enumerate(ages)])
a_lookup    = [a_list[data.age_group[i]] for i in np.arange(len(data))]
a_by_g      = [[a_list[data.age_group[i]] for i in g_indices[g]] for g in g_list]

'''
Y_g,t,a ~ NegativeBinomial(mu_g,t,a , omega)

    where   g: geography (state)
            t: time (year)
            a: age

    Y_g,t,a	    <- observed deaths in a state/year/age

    mu_g,t,a	<- exp(beta + pi_g,t,a + ln(E_g,t,a) + eps_g,t,a)

        beta        ~ Normal(0, 100)
                      overall intercept (mean total mortality rate across state/year/age)

        alpha_t,a   ~ MVN(0, matern(y, a))
                      smooth surface over time/age which describes deviation from overall mean

        pi_g,t,a    ~ MVN(alpha_t,a, matern_g(y, a))
                      smooth surface over time/age which describes how state g deviates from national mortality pattern
        
        E           <- exposure (i.e. population)
        
        eps_g,t,a   ~ error
    
    omega       ~ overdispersion parameter
'''

# grid to sample time/age over
sample_points = []
for a in sample_ages:
    for t in sample_years:
        sample_points.append([a, t])
sample_points = np.array(sample_points)

# overall intercept (corresponds to average death rate across time/space/age)
beta = mc.Normal(
        name =  'beta_0', 
        mu =    0., 
        tau =   1./100**2,
        value = 0.)

# national time/age pattern
matern_alpha = mc.gp.cov_funs.matern.euclidean(
        x =         sample_points, 
        y =         sample_points, 
        amp =       5., 
        scale =     5., 
        diff_degree=2., 
        symm =      True)
alpha_samples = mc.MvNormalCov(
        name =  'alpha_samples', 
        mu =    np.zeros(sample_points.shape[0]), 
        C =     matern_alpha, 
        value = np.zeros(sample_points.shape[0]))

# time/age deviation by state
matern_pi = mc.gp.cov_funs.matern.euclidean(
        x =         sample_points, 
        y =         sample_points, 
        amp =       5., 
        scale =     5., 
        diff_degree=2., 
        symm =      True)
pi_samples = [mc.MvNormalCov(
        name =      'pi_%s_samples' %g, 
        mu =        np.zeros(sample_points.shape[0]), 
        C =         matern_pi, 
        value =     np.zeros(sample_points.shape[0]))
        for g in g_list]

# deterministic function to extrapolate out national pattern by age/year
def alpha_interpolator(alpha_samples):
    interpolator = interpolate.fitpack2.RectBivariateSpline(
        x =     sample_ages,
        y =     sample_years,
        z =     alpha_samples.reshape((len(sample_ages), len(sample_years))),
        bbox =  [sample_ages[0], sample_ages[-1], sample_years[0], sample_years[-1]],
        kx =    3,
        ky =    3)
    return interpolator(x=ages, y=years)
alpha_surf = mc.Deterministic(
                eval =      alpha_interpolator,
                name =      'alpha_surf',
                parents =   {'alpha_samples': alpha_samples},
                doc =       'National random effect surface')
@mc.deterministic
def alpha_re(alpha_surf=alpha_surf):
    return alpha_surf[a_lookup, t_lookup]

# deterministics to extrapolate state level random effects out by age/year
def pi_interpolator(pi_sample):
    interpolator = interpolate.fitpack2.RectBivariateSpline(
        x =     sample_ages,
        y =     sample_years,
        z =     pi_sample.reshape((len(sample_ages), len(sample_years))),
        bbox =  [sample_ages[0], sample_ages[-1], sample_years[0], sample_years[-1]],
        kx =    3, 
        ky =    3)
    return interpolator(x=ages, y=years)
pi_surf = [mc.Deterministic(
            eval =      pi_interpolator,
            name =      'pi_surf_%s' % g,
            parents =   {'pi_sample': pi_samples[i]},
            doc =       'Random effect surface for state %s (%s)' % (g, state_lookup[g])) 
          for i, g in enumerate(g_list)]
@mc.deterministic
def pi_re(pi_surf=pi_surf):
    pi_array =  np.zeros(len(data))
    for i, g in enumerate(g_list):
        pi_array[g_indices[g]] = pi_surf[i][a_by_g[i], t_by_g[i]]
    return pi_array

# find exposure
E = np.log(data.pop)

# prediction from above parameters
@mc.deterministic
def predicted(beta=beta, alpha_re=alpha_re, pi_re=pi_re):
    return np.round(np.exp(np.vstack([alpha_re, pi_re]).sum(axis=0) + beta))

# overdispersion parameter
rho = mc.Normal('rho', mu=8., tau=.1, value=8.)
@mc.deterministic
def omega(rho=rho):
    return 10.**rho

# negative binomial likelihood
@mc.observed
def data_likelihood(value=data.deaths, mu=predicted, alpha=omega):
    if alpha >= 10**10:
        return mc.poisson_like(value, mu)
    else:
        if mu.min() <= 0.:
            mu = mu + 10.**-10
        return mc.negative_binomial_like(value, mu, alpha)

# model
model = mc.MCMC(vars(), db='ram')

# MCMC step methods
model.use_step_method(mc.AdaptiveMetropolis, [model.beta, model.rho, model.alpha_samples], interval=100)
for i, g in enumerate(g_list):
    model.use_step_method(mc.AdaptiveMetropolis, model.pi_samples[i], interval=100)

# use map to find starting values
for var_list in [[model.data_likelihood, model.beta, model.rho]] + \
                [[model.data_likelihood, model.alpha_samples]] + \
                [[model.data_likelihood, model.beta, model.rho]] + \
                [[model.data_likelihood, model.alpha_samples]] + \
                [[model.data_likelihood, model.alpha_samples, model.beta, model.rho]] + \
                [[model.data_likelihood, g] for g in model.pi_samples]:
    print 'attempting to maximize liklihood of %s' % [v.__name__ for v in var_list]
    mc.MAP(var_list).fit(method='fmin_powell', verbose=1)
    print ''.join(['%s: %s\n' % (v.__name__, v.value) for v in var_list[1:]])

# draw some samples
model.sample(iter=100000, burn=90000, thin=10, verbose=1)
# model.sample(iter=1, burn=0, thin=1, verbose=1)

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

import time
print 'Finished at %s' % time.ctime()

# save basic predictions
predictions =       model.trace('predicted')[:]
mean_prediction =   predictions.mean(axis=0)
lower_prediction =  percentile(predictions, 2.5, axis=0)
upper_prediction =  percentile(predictions, 97.5, axis=0)
output =            pl.rec_append_fields(  rec =   data, 
                        names = ['mean', 'lower', 'upper'], 
                        arrs =  [mean_prediction, lower_prediction, upper_prediction])
pl.rec2csv(output, proj_dir + 'outputs/model results/epi transition by state/all_cause_males.csv')

# plot surfaces
from    mpl_toolkits.mplot3d    import axes3d
import  matplotlib.pyplot       as plt
from    matplotlib.backends.backend_pdf import PdfPages
pp =    PdfPages(proj_dir + 'outputs/model results/epi transition by state/surfaces.pdf')
fig =   plt.figure()
ax =    fig.gca(projection='3d')
X,Y =   np.meshgrid(years, ages)
Z =     model.trace('alpha_surf')[:].mean(axis=0)
ax.plot_wireframe(X, Y, Z, color='#315B7E')
ax.set_title('National')
pp.savefig()
for g in g_list:
    fig =   plt.figure()
    ax =    fig.gca(projection='3d')
    Z =     model.trace('pi_surf_%s' % g)[:].mean(axis=0)
    ax.plot_wireframe(X, Y, Z, color='#315B7E')
    ax.set_title(state_lookup[g])
    pp.savefig()
    plt.close()
pp.close()

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
