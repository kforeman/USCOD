# import external libraries
import  pymc    as mc
import  numpy   as np
import  pylab   as pl
from    scipy   import sparse
import  inspect

# import submodules
import  Components

# define model class
class USCOD:

    def __init__(self, model_name, sex, age):
        
        # check to make sure the initialization arguments work
        if type(model_name) != str:
            raise ValueError('Model name must be a string.')
        if sex != 1 & sex !=2:
            raise ValueError('Specify sex as either 1 (male) or 2 (female).')
        try:
            ['Under5', '5to14', '15to29', '30to44', '45to59', '60to74', '75plus'].index(age)
        except ValueError:
            raise ValueError('Age %s not found.' % age)

        # save initialization arguments
        self.model_name =   model_name
        self.sex =          sex
        self.age =          age
        
        # start the model with no components in place
        self.included_components =  []

    
    
    def load_data(self, csv='D:/projects/USCOD/data/model inputs/state_random_effects_input.csv'):
        '''
        load the data from csv
        ### Note: for now, only takes in data as a csv
            TODO: enable MySQL download
        '''
        
        # load the csv file
        self.data =     pl.csv2rec(csv)
        
        # keep just the specified age and sex
        self.data =     self.data[(self.data.sex == self.sex) & (self.data.age_group == self.age)]

        # remove any instances of population zero, which might blow things up due to having offsets of negative infinity
        self.data =     self.data[self.data.pop > 0.]
        
        # report how many rows were loaded
        print '%g rows of data loaded.' % len(self.data)



    def list_components(self):
        '''
        return components inserted into the model so far
        '''

        # list current components
        print 'Currently included components:'
        for c in self.included_components:
            print '%s:\n\t%s' % (c.__name__, c.__doc__)
        if len(self.included_components) == 0:
            print 'None'
            
        # list available components
        print '\nAvailable components:'
        for c in Components.available_components:
            print '%s:\n\t%s' % (c.__name__, c.__doc__)

            
            
    def add_components(self, new_components):
        '''
        add new components to a model
        can either be a single component or a list of components
        use list_components() to see a list of what's available
        '''
        if type(new_components) != list:
            new_components = [new_components]
        for c in new_components:
            if self.included_components.count(c) == 0:
                self.included_components.append(c)
                print 'Added %s to model' % c.__name__
            else:
                print 'Skipped %s because it is already in the model' % c.__name__
        

            
    def list_parameters(self, components=[]):
        '''
        returns all the parameters associated with a given set of components
        '''
        if type(components) != list:
            components = [components]
        if components == []:
            components = self.included_components
        for c in components:
            params =    inspect.getargspec(c)
            print params.args
        
            
            
            
            
class Component:
    def __init__(self, a):
        self.a = a
    def __call__:
        return self.a
            
class RandomEffect(Component):
    def set_unit(self, unit)
        self.unit = unit
            
            
            
            
            
            
'''

import os
os.chdir('D:/projects/USCOD/code/model/modular')
import uscod
t = uscod.USCOD('test', 1, 'Under5')

'''
        
