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

    mu_g,t,a	<- exp(beta_0 + pi_g,t,a + ln(E_g,t,a) + eps_g,t,a)

        beta        ~ Normal(0, 100)
                      overall intercept (mean total mortality rate across state/year/age)

        alpha_t,a   ~ MVN(0, matern(y, a))
                      smooth surface over time/age which describes deviation from overall mean

        pi_g,t,a    ~ MVN(0, matern_g(y, a))
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

# deterministic functions to extrapolate out by age/year
@mc.deterministic
def alpha(alpha_samples=alpha_samples):
    interpolator = interpolate.fitpack2.RectBivariateSpline(
            x =     sample_ages, 
            y =     sample_years, 
            z =     alpha_samples.reshape((len(sample_ages), len(sample_years))), 
            bbox =  [sample_ages[0], sample_ages[-1], sample_years[0], sample_years[-1]],
            kx =    3, 
            ky =    3)
    return interpolator(x=ages, y=years)[a_lookup, t_lookup]

@mc.deterministic
def pi(pi_samples=pi_samples):
    pi_array =  np.zeros(len(data))
    for i, g in enumerate(g_list):
        interpolator = interpolate.fitpack2.RectBivariateSpline(
                x =     sample_ages,
                y =     sample_years,
                z =     pi_samples[i].reshape((len(sample_ages), len(sample_years))),
                bbox =  [sample_ages[0], sample_ages[-1], sample_years[0], sample_years[-1]],
                kx =    3, 
                ky =    3)
        pi_array[g_indices[g]] = interpolator(x=ages, y=years)[a_by_g[i], t_by_g[i]]
    return pi_array

# find exposure
E = np.log(data.pop)

# prediction from above parameters
@mc.deterministic
def predicted(beta=beta, alpha=alpha, pi=pi):
    return np.round(np.exp(np.vstack([alpha, pi]).sum(axis=0) + beta))

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
                [[model.data_likelihood, g] for g in model.pi_samples]:
    print 'attempting to maximize liklihood of %s' % [v.__name__ for v in var_list]
    mc.MAP(var_list).fit(method='fmin_powell', verbose=1)
    print ''.join(['%s: %s\n' % (v.__name__, v.value) for v in var_list[1:]])

# draw some samples
model.sample(iter=11000, burn=1000, thin=10, verbose=1)











