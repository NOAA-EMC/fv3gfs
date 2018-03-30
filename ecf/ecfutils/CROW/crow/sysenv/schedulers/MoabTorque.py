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
        self.rocoto_name='MoabTorque'
        self.indent_text=str(settings.get('indent_text','  '))

    def max_ranks_per_node(self,spec):
        if not spec.is_pure_serial() and not spec.is_pure_openmp():
            # MPI program.  Merge ranks if allowed.
            spec=self.nodes.with_similar_ranks_merged(
                spec,can_merge_ranks=self.nodes.same_except_exe)
        return max([ self.nodes.max_ranks_per_node(j) for j in spec ])

    ####################################################################

    # Batch card generation

    def batch_accounting(self,spec,**kwargs):
        if kwargs:
            spec=dict(spec,**kwargs)
        space=self.indent_text
        sio=StringIO()
        if 'queue' in spec:
            sio.write(f'#PBS -q {spec["queue"]!s}\n')
        if 'project' in spec:
            sio.write(f'#PBS -A {spec["project"]!s}\n')
        if 'partition' in spec:
            sio.write(f'#PBS -l partition={spec["partition"]!s}\n')
        if 'account' in spec:
            sio.write(f'#PBS -A {spec["account"]!s}\n')
        ret=sio.getvalue()
        sio.close()
        return ret

    def get_memory_from_resource_spec(self,spec):
        for memvar in [ 'compute_memory', 'memory' ]:
            memory=spec[0].get(memvar,'')
            if not memory: continue
            bytes=tools.memory_in_bytes(memory)
            return int(math.ceil(bytes/1048576.))
        return None

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
            sio.write(f'#PBS -l walltime={hours:d}:{minutes:02d}'
                      f':{seconds:02d}\n')

        megabytes=self.get_memory_from_resource_spec(spec)
        if megabytes is not None:
            sio.write(f'#PBS -l vmem={megabytes:d}M\n')

        if spec[0].get('outerr',''):
            sio.write(f'#PBS -j oe -o {spec[0]["outerr"]}\n')
        else:
            if spec[0].get('stdout',''):
                sio.write('#PBS -o {spec[0]["stdout"]}\n')
            if spec[0].get('stderr',''):
                sio.write('#PBS -e {spec[0]["stderr"]}\n')
        if spec[0].get('jobname'):
            sio.write('#PBS -J {spec[0]["jobname"]}\n')

        # --------------------------------------------------------------
        # Request processors.
        if spec.is_pure_serial():
            if spec[0].is_exclusive() in [True,None]:
                sio.write('#PBS -l nodes=1:ppn=2\n')
            else:
                sio.write('#PBS -l procs=1\n')
        elif spec.is_pure_openmp():
            # Pure threaded.  Treat as exclusive serial.
            sio.write('#PBS -l nodes=1:ppn=2\n')
        else:
            # This is an MPI program.

            # Split into (nodes,ranks_per_node) pairs.  Ignore
            # differing executables between ranks while merging them
            # (del_exe):
            nodes_ranks=self.nodes.to_nodes_ppn(
                spec,can_merge_ranks=self.nodes.same_except_exe)
            sio.write('#PBS -l nodes=')
            sio.write('+'.join([f'{n}:ppn={p}' for n,p in nodes_ranks ]))
            sio.write('\n')
        ret=sio.getvalue()
        sio.close()
        return ret

    ####################################################################
    
    # Rocoto XML generation

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
        if 'partition' in spec:
            sio.write(f'{indent*space}<native>-l partition='
                      f'{spec["partition"]!s}</native>\n')
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
       
        megabytes=self.get_memory_from_resource_spec(spec)
        if megabytes is not None:
            sio.write(f'{indent*space}<memory>{megabytes:d}M</memory>\n')

        if 'outerr' in spec:
            sio.write(f'{indent*space}<join>{spec["outerr"]}</join>\n')
        else:
            if 'stdout' in spec:
                sio.write('{indent*space}<stdout>{spec["stdout"]}</stdout>\n')
            if 'stderr' in spec:
                sio.write('{indent*space}<stderr>{spec["stderr"]}</stderr>\n')

        if spec.is_pure_serial():
            if spec[0].is_exclusive() in [True,None]:
                sio.write(indent*space+'<nodes>1:ppn=2</nodes>\n')
            else:
                sio.write(indent*space+'<cores>1</cores>\n')
        elif spec.is_pure_openmp():
            # Pure threaded.  Treat as exclusive serial.
            sio.write(indent*space+'<nodes>1:ppn=2</nodes>\n')
        else:
            # This is an MPI program.
            
            # Split into (nodes,ranks_per_node) pairs.  Ignore differeing
            # executables between ranks while merging them (del_exe):
            nodes_ranks=self.nodes.to_nodes_ppn(
                spec,can_merge_ranks=self.nodes.same_except_exe)
            
            sio.write(indent*space+'<nodes>' \
                + '+'.join([f'{n}:ppn={p}' for n,p in nodes_ranks ]) \
                + '</nodes>\n')
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

