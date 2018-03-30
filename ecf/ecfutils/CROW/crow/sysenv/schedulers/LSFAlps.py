import itertools, math
from io import StringIO

import crow.tools as tools
from crow.sysenv.exceptions import *
from crow.sysenv.util import ranks_to_nodes_ppn
from crow.sysenv.jobs import JobResourceSpec
from crow.sysenv.nodes import GenericNodeSpec

from crow.sysenv.schedulers.base import Scheduler as BaseScheduler

from collections import Sequence

__all__=['Scheduler']

class Scheduler(BaseScheduler):

    def __init__(self,settings,**kwargs):
        self.settings=dict(settings)
        self.settings.update(kwargs)
        self.nodes=GenericNodeSpec(settings)
        self.rocoto_name='lsfcray'
        self.indent_text=str(settings.get('indent_text','  '))

    def max_ranks_per_node(self,spec):
        return max([ self.nodes.max_ranks_per_node(j) for j in spec ])

    ####################################################################

    # Generation of batch cards

    def batch_accounting(self,spec,**kwargs):
        if kwargs:
            spec=dict(spec,**kwargs)
        space=self.indent_text
        sio=StringIO()
        if 'queue' in spec:
            sio.write(f'#BSUB -q {spec["queue"]!s}\n')
        if 'project' in spec:
            sio.write(f'#BSUB -P {spec["project"]!s}\n')
        if 'account' in spec:
            sio.write(f'#BSUB -P {spec["account"]!s}\n')
        if 'jobname' in spec:
            sio.write(f'#BSUB -J {spec["jobname"]!s}\n')
        if 'outerr' in spec:
            sio.write(f'#BSUB -o {spec["outerr"]}\n')
        else:
            if 'stdout' in spec:
                sio.write('#BSUB -o {spec["stdout"]}\n')
            if 'stderr' in spec:
                sio.write('#BSUB -e {spec["stderr"]}\n')
        ret=sio.getvalue()
        sio.close()
        return ret

    def batch_resources(self,spec,**kwargs):
        if kwargs:
            spec=dict(spec,**kwargs)
        space=self.indent_text
        sio=StringIO()
        if not isinstance(spec,JobResourceSpec):
            spec=JobResourceSpec(spec)

        result=''
        if spec[0].get('walltime',''):
            dt=tools.to_timedelta(spec[0]['walltime'])
            dt=dt.total_seconds()
            hours=int(dt//3600)
            minutes=int((dt%3600)//60)
            seconds=int(math.floor(dt%60))
            sio.write(f'#BSUB -W {hours}:{minutes:02d}\n')

        # Handle memory.
        if spec[0].is_exclusive() and spec[0].get('batch_memory',''):
            bytes=tools.memory_in_bytes(spec[0]['batch_memory'])
        elif not spec[0].is_exclusive() and spec[0].get('compute_memory',''):
            bytes=tools.memory_in_bytes(spec[0]['compute_memory'])
        elif spec[0].get('memory',''):
            bytes=tools.memory_in_bytes(spec[0]['memory'])
        else:
            bytes=2000*1048576.

        megabytes=int(math.ceil(bytes/1048576.))

        sio.write(f'#BSUB -R rusage[mem={megabytes:d}]\n')

        if spec[0].get('outerr',''):
            sio.write(f'#BSUB -o {spec[0]["outerr"]}\n')
        else:
            if spec[0].get('stdout',''):
                sio.write('#BSUB -o {spec[0]["stdout"]}\n')
            if spec[0].get('stderr',''):
                sio.write('#BSUB -e {spec[0]["stderr"]}\n')
        # --------------------------------------------------------------

        # With LSF+ALPS on WCOSS Cray, to my knowledge, you can only
        # request one node size for all ranks.  This code calculates
        # the largest node size required (hyperthreading vs. non)

        requested_nodes=1

        nodesize=max([ self.nodes.node_size(r) for r in spec ])

        if spec[0].is_exclusive() is False:
            # Shared program.  This requires a different batch card syntax            
            nranks=max(1,spec.total_ranks())
            sio.write(f'#BSUB -n {nranks}\n')
        else:
            if not spec.is_pure_serial() and not spec.is_pure_openmp():
                # This is an MPI program.
                nodes_ranks=self.nodes.to_nodes_ppn(spec)
                requested_nodes=sum([ n for n,p in nodes_ranks ])
            sio.write('#BSUB -extsched CRAYLINUX[]\n')
            if self.settings.get('use_export_nodes',True):
                sio.write(f'export NODES={requested_nodes}')
            else:
                sio.write("#BSUB -R '1*{select[craylinux && !vnode]} + ")
                sio.write('%d'%requested_nodes)
                sio.write("*{select[craylinux && vnode]span[")
                sio.write(f"ptile={nodesize}] cu[type=cabinet]}}'")
        
        ret=sio.getvalue()
        sio.close()
        return ret

    ####################################################################

    # Generation of Rocoto XML

    def rocoto_accounting(self,spec,indent=0,**kwargs):
        if kwargs:
            spec=dict(spec,**kwargs)
        space=self.indent_text
        sio=StringIO()
        if 'queue' in spec:
            sio.write(f'{indent*space}<queue>{spec["queue"]!s}</queue>\n')
        if 'account' in spec:
            sio.write(f'{indent*space}<account>{spec["account"]!s}</account>\n')
        if 'project' in spec:
            sio.write(f'{indent*space}<account>{spec["project"]!s}</account>\n')
        if 'account' in spec:
            sio.write(f'{indent*space}<account>{spec["account"]!s}</account>\n')
        if 'jobname' in spec:
            sio.write(f'{indent*space}<jobname>{spec["jobname"]!s}</jobname>\n')
        if 'outerr' in spec:
            sio.write(f'{indent*space}<join>{spec["outerr"]}</join>\n')
        else:
            if 'stdout' in spec:
                sio.write('{indent*space}<stdout>{spec["stdout"]}</stdout>\n')
            if 'stderr' in spec:
                sio.write('{indent*space}<stderr>{spec["stderr"]}</stderr>\n')
        ret=sio.getvalue()
        sio.close()
        return ret

    def rocoto_resources(self,spec,indent=0):
        sio=StringIO()
        space=self.indent_text
        if not isinstance(spec,JobResourceSpec):
            spec=JobResourceSpec(spec)

        if spec[0].get('walltime',''):
            dt=tools.to_timedelta(spec[0]['walltime'])
            dt=dt.total_seconds()
            hours=int(dt//3600)
            minutes=int((dt%3600)//60)
            seconds=int(math.floor(dt%60))
            sio.write(f'{indent*space}<walltime>{hours}:{minutes:02d}:{seconds:02d}</walltime>\n')
       

        # Handle memory.
        if spec[0].is_exclusive() and spec[0].get('batch_memory',''):
            bytes=tools.memory_in_bytes(spec[0]['batch_memory'])
        elif not spec[0].is_exclusive() and spec[0].get('compute_memory',''):
            bytes=tools.memory_in_bytes(spec[0]['compute_memory'])
        elif spec[0].get('memory',''):
            bytes=tools.memory_in_bytes(spec[0]['memory'])
        else:
            bytes=2000*1048576.

        megabytes=int(math.ceil(bytes/1048576.))

        sio.write(f'{indent*space}<memory>{megabytes:d}M</memory>\n')

        if 'outerr' in spec:
            sio.write(f'{indent*space}<join>{spec["outerr"]}</join>\n')
        else:
            if 'stdout' in spec:
                sio.write('{indent*space}<stdout>{spec["stdout"]}</stdout>\n')
            if 'stderr' in spec:
                sio.write('{indent*space}<stderr>{spec["stderr"]}</stderr>\n')


        nodesize=max([ self.nodes.node_size(r) for r in spec ])
        requested_nodes=1

        if spec[0].is_exclusive() is False:
            # Shared program.  This requires a different batch card syntax            
            nranks=max(1,spec.total_ranks())
            sio.write(f'{indent*space}<cores>{max(1,spec.total_ranks())}</cores>\n'
                      f'{indent*space}<shared></shared>\n')
        else:
            if not spec.is_pure_serial() and not spec.is_pure_openmp():
                # This is an MPI program.
                nodes_ranks=self.nodes.to_nodes_ppn(spec)
                requested_nodes=sum([ n for n,p in nodes_ranks ])

            nodes_ranks=self.nodes.to_nodes_ppn(
                spec,can_merge_ranks=lambda x,y: False)
            
            sio.write(indent*space+'<nodes>' \
                + '+'.join([f'{max(n,1)}:ppn={max(p,1)}' for n,p in nodes_ranks ]) \
                + '</nodes>\n')

            #sio.write(f'{indent*space}<nodes>{requested_nodes}:ppn={nodesize}</nodes>')
        ret=sio.getvalue()
        sio.close()
        return ret

def test():
    settings={ 'physical_cores_per_node':24,
               'logical_cpus_per_core':2,
               'hyperthreading_allowed':True }
    sched=Scheduler(settings)

    # MPI + OpenMP program test
    input1=[
        {'mpi_ranks':5, 'OMP_NUM_THREADS':12},
        {'mpi_ranks':7, 'OMP_NUM_THREADS':12},
        {'mpi_ranks':7} ]
    spec1=JobResourceSpec(input1)
    result=sched.rocoto_resources(spec1)
    assert(result=='<nodes>6:ppn=2+1:ppn=7</nodes>\n')

    # Serial program test
    input2=[ { 'exe':'echo', 'args':['hello','world'], 'exclusive':False } ]
    spec2=JobResourceSpec(input2)
    assert(sched.rocoto_resources(spec2)=='<cores>1</cores>\n')

    # Exclusive serial program test
    input3=[ { 'exe':'echo', 'args':['hello','world 2'], 'exclusive':True } ]
    spec3=JobResourceSpec(input3)
    result=sched.rocoto_resources(spec3)
    assert(result=='<nodes>1:ppn=2</nodes>\n')

    # Pure openmp test
    input4=[ { 'OMP_NUM_THREADS':20 } ]
    spec4=JobResourceSpec(input4)
    result=sched.rocoto_resources(spec4)
    assert(result=='<nodes>1:ppn=2</nodes>\n')

    # Too big for node
    try:
        input5=[ { 'OMP_NUM_THREADS':200, 'mpi_ranks':3 } ]
        spec5=JobResourceSpec(input5)
        result=sched.rocoto_resources(spec5)
        assert(False)
    except MachineTooSmallError:
        pass # success!

