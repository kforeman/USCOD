def global_intercept(USCOD, tau=1e-4):
    '''global intercept'''
    return mc.Normal(   
                        name =  'global_intercept', 
                        mu =    0.,
                        tau =   tau,
                        value = 0.
                    )

def spatial_intercept():
    '''random effect by geographic unit'''
    

available_components = [eval(c) for c in dir() if c[0:2] != '__']

