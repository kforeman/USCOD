# import external libraries
import  pymc    as mc
import  numpy   as np
import  pylab   as pl
from    scipy   import sparse
import  inspect

# define model class
class Model:
    '''
    Provide the model name (any string), sex (1=male or 2=female), and age ('Under5', '5to14', '15to29', '30to44', '45to59', '60to74', '75plus')
    '''

    def __init__(self, model_name, sex, age, csv='D:/projects/USCOD/data/model inputs/state_random_effects_input.csv'):
        
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
        self.registered_components =  []
        
        # load the data
        self.load_data(csv)

    
    
    def load_data(self, csv):
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
        for c in self.registered_components:
            print '%s:\n\t%s' % (c.__name__, c.__doc__)
        if len(self.registered_components) == 0:
            print 'None'

            
            
    def list_parameters(self, components=[]):
        '''
        returns all the parameters associated with a given set of components
        '''
        if type(components) != list:
            components = [components]
        if components == []:
            components = self.registered_components
        for c in components:
            params =    inspect.getargspec(c)
            print params.args
        
            
            
            
class Component:
    def __init__(self, parent, component_name):
        self.parent = parent
        self.component_name = component_name
    def __call__(self):
        return self.a
    def register(self):
        '''
        Registers this model component to a parent model
        If the component already exists, then deregisters and reregisters it
        '''
        if self.parent.registered_components.count(self) == 0:
            self.parent.registered_components.append(self)
            print 'Added component %s to model %s.' % (self.component_name, self.parent.model_name)
        else:
            self.deregister()
            self.parent.registered_components.append(self)
            print 'Reregistered component %s in model %s.' % (self.component_name, self.parent.model_name)
    def deregister(self):
        '''
        Removes component from the model
        '''
        if self.parent.registered_components.count(self) == 0:
            raise ValueError('Component %s not found in model %s.' % (self.component_name, self.parent.model_name))
        else:
            self.parent.registered_components.remove(self)
            print 'Removed existing component %s from model %s.' % (self.component_name, self.parent.model_name)
        
            
class RandomEffect(Component):
    def set_unit(self, unit):
        self.unit = unit
            

            
            
            
            
'''

import os
os.chdir('D:/projects/USCOD/code/model/modular')
import uscod
t = uscod.Model('test', 1, 'Under5')
x = uscod.Component(t, 'blah')
x.register()

'''
        
