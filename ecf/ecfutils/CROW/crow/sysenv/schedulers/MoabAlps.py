from .MoabTorque import Scheduler as MoabTorqueScheduler

import math
import crow.tools as tools

__all__=['Scheduler']

class Scheduler(MoabTorqueScheduler):
    def __init__(self,settings,**kwargs):
        super().__init__(settings,**kwargs)
        self.rocoto_name='Moab'

    def get_memory_from_resource_spec(self,spec):
        if self.settings.get('memory_limits',False):
            for memvar in [ 'batch_memory', 'memory' ]:
                memory=spec[0].get(memvar,'')
                if not memory: continue
                bytes=tools.memory_in_bytes(memory)
                return int(math.ceil(bytes/1048576.))
        return None

