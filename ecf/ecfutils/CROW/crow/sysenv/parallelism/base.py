from abc import abstractmethod
from ..jobs import JobResourceSpec

class Parallelism(object):
    @abstractmethod
    def make_ShellCommand(self,spec): pass

    def run(self,spec,*args,**kwargs):
        if not isinstance(spec,JobResourceSpec):
            spec=JobResourceSpec(spec)
        cmd=self.make_ShellCommand(spec)
        return cmd.run(*args,**kwargs)
