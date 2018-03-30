import itertools
from io import StringIO

from crow.sysenv.exceptions import *
from crow.sysenv.util import ranks_to_nodes_ppn
from crow.sysenv.jobs import JobResourceSpec
from crow.sysenv.shell import ShellCommand
from crow.sysenv.nodes import GenericNodeSpec

from crow.sysenv.parallelism.base import Parallelism as BaseParallelism

from collections import Sequence

__all__=['Parallelism']

class Parallelism(BaseParallelism):  # (BaseParallelism):
    def __init__(self,settings):
        self.settings=dict(settings)
        self.nodes=GenericNodeSpec(settings)
        self.parallelism='HydraIMPI'
        self.mpi_runner=str(settings.get('mpi_runner','mpirun'))
        self.rank_sep=str(settings.get('rank_sep',':'))

    def make_ShellCommand(self,spec):
        if spec.is_pure_serial():
            return ShellCommand(spec['exe'])
        elif spec.is_pure_openmp():
            return ShellCommand(spec[0]['exe'],env={
                'OMP_NUM_THREADS':self.nodes.omp_threads_for(spec[0])})

        # Merge any adjacent ranks that can be merged.  Ignore
        # differing executables between ranks while merging them
        # (rename_exe):
        merged=self.nodes.with_similar_ranks_merged(
            spec,can_merge_ranks=self.nodes.same_except_exe)

        cmd=[ self.mpi_runner ]

        first=True
        for rank in merged:
            if not first and self.rank_sep:
                cmd.append(self.rank_sep)
            exe=rank['exe']

            # Add extra arguments specific to this MPI.  Note:
            # "extras" go first so that the first block of ranks can
            # specify the hydra global options.
            extra=rank.get('HydraIMPI_extra',None)
            if extra is not None:
                if isinstance(extra,str): extra=[extra]
                cmd.extend(extra)

            cmd.extend(['-np','%d'%max(1,int(rank.get('mpi_ranks',1)))])
            if rank.is_openmp():
                cmd.extend([ '/usr/bin/env', 'OMP_NUM_THREADS='+
                             '%d'%self.nodes.omp_threads_for(rank) ])
            if isinstance(exe,str):
                cmd.append(exe)
            else:
                cmd.extend(exe)
            first=False

        return ShellCommand(cmd)
        
                
    
