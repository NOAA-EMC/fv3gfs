from abc import abstractmethod

class Scheduler(object):
    @abstractmethod
    def rocoto_accounting(self,spec,indent): pass
    @abstractmethod
    def rocoto_resources(self,spec,indent): pass
    @abstractmethod
    def max_ranks_per_node(job_spec): pass
    @abstractmethod
    def batch_accounting(self,spec,**kwargs): pass
    @abstractmethod
    def batch_resources(self,spec,**kwargs): pass
