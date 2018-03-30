import crow.tools
from abc import abstractmethod
from collections import UserList, Mapping, Sequence, OrderedDict
from subprocess import Popen, PIPE, CompletedProcess
from crow.sysenv.jobs import MAXIMUM_THREADS
from crow.sysenv.util import ranks_to_nodes_ppn
from crow.tools import typecheck
from crow.sysenv.exceptions import *

def noop(*args,**kwargs): pass

def node_tool_for(node_type,settings):
    if node_type != "generic":
        raise UnknownNodeType(f"No such node type: {node_type}")
    return GenericNodeSpec(settings)

########################################################################

class NodeSpec(object):
    """!Abstract base class to represent a block of compute nodes.
    Provides derived information about the nodes based on JobRankSpec
    and JobResourceSpec objects.    """
    @abstractmethod
    def max_ranks_per_node(rank_spec):
        """!Given a JobRankSpec, return the maximum number of these ranks that
        can fit on one compute node.        """
    @abstractmethod
    def omp_threads_for(rank_spec):
        """!Given a JobRankSpec, return the number of OpenMP threads it should
        use.  This will perform the OMP_NUM_THREADS=max calculation if the
        number of OpenMP threads is unspecified."""
    @abstractmethod
    def can_merge_ranks(rank_spec_1,rank_spec_2):
        """!Given two JobRankSpec objects, determine whether they can be 
        merged into one."""
    @abstractmethod
    def same_except_exe(rank_spec_1,rank_spec_2):
        """!Same as can_merge_ranks, but ignores executables and arguments."""

    @abstractmethod
    def node_size(rank_spec):
        """!Returns the maximum possible number of ranks per node.
        The rank_spec is used to check if hyperthreading is requested."""

    # ----------------------------------------------------------------
    # Utility functions.
    # ----------------------------------------------------------------

    def node_ppn_pairs_for_mpi_spec(self,spec,can_merge_ranks=None):
        """!Given a JobResourceSpec, return (nodes, ppn) pairs of integers
        specifying the number nodes and number of processors on that
        bank of nodes.  This is intended to generate PBS-style
        "-lnodes=1:ppn=5+6:ppn=8" resource specifications        """
        can_merge_ranks = can_merge_ranks or self.can_merge_ranks
        nodes_ranks=node_ppn_pairs_for_mpi_spec(
            spec,self.max_ranks_per_node,can_merge_ranks)

    def merge_similar_ranks(self,ranks,can_merge_ranks):
        """!Given an array of JobRankSpec, merge any contiguous sequence of
        JobRankSpec objects where self.can_merge_ranks(rank1,rank2)
        returns true.  This is done in-place; the input is modified.   """
        can_merge_ranks = can_merge_ranks or self.can_merge_ranks
        i=0
        while i<len(ranks)-1:
            if can_merge_ranks(ranks[i],ranks[i+1]):
                ranks[i]=ranks[i].new_with(
                    mpi_ranks=ranks[i]['mpi_ranks']+ranks[i+1]['mpi_ranks'])
                del ranks[i+1]
            else:
                i=i+1
    
    def with_similar_ranks_merged(self,spec,rank_simplifier=None,
                                  can_merge_ranks=None):
        """!Given a JobResourceSpec, return a new one with all similar ranks
        merged.  The rank_simplifier function is run on each rank
        before merging all of them.        """
        can_merge_ranks = can_merge_ranks or self.can_merge_ranks
        rank_simplifier = rank_simplifier or noop
        def merge(merge_me):
            self.merge_similar_ranks(merge_me,can_merge_ranks)
        return spec.simplify(merge,rank_simplifier)

    def to_nodes_ppn(self,spec,rank_simplifier=None,
                     can_merge_ranks=None):
        """!Given a JobResourceSpec that represents an MPI program, express 
        it in (nodes,ranks_per_node) pairs where each is an integer.
        This is intended to be used to generate PBS-style
        "nodes=1:ppn=3+8:ppn=12" specifications.        """
        spec=self.with_similar_ranks_merged(spec,rank_simplifier,
                                            can_merge_ranks)
        # Get the (nodes,ppn) pairs for all ranks:
        nodes_ranks=list()
        for block in spec:
            max_per_node=self.max_ranks_per_node(block)
            ranks=block['mpi_ranks']
            kj=ranks_to_nodes_ppn(max_per_node,ranks)
            nodes_ranks.extend(kj)
        return nodes_ranks

########################################################################

class GenericNodeSpec(NodeSpec):
    def __init__(self,settings):
        self.settings=dict(settings)
        self.cores_per_node=int(settings['physical_cores_per_node'])
        self.cpus_per_core=int(settings.get('logical_cpus_per_core',1))
        self.hyperthreading_allowed=bool(
            settings.get('hyperthreading_allowed',False))
        self.indent_text=str(settings.get('indent_text','  '))

    # Implement NodeSpec abstract methods:

    def omp_threads_for(self,rank_spec):
        typecheck('rank_spec',rank_spec,crow.sysenv.jobs.JobRankSpec)
        omp_threads=max(1,rank_spec.get('OMP_NUM_THREADS',1))
        if omp_threads != MAXIMUM_THREADS:
            return omp_threads

        can_hyper=self.hyperthreading_allowed
        max_ranks_per_node=self.cores_per_node
        if can_hyper and rank_spec.get('hyperthreading',False):
            max_ranks_per_node*=self.cpus_per_core
        if rank_spec.is_mpi():
            ppn=max_ranks_per_node
        else:
            ppn=1

        max_ppn=rank_spec.get('max_ppn',0)
        if max_ppn:
            ppn=min(max_ppn,ppn)

        return max_ranks_per_node//ppn

    def max_ranks_per_node(self,rank_spec):
        typecheck('rank_spec',rank_spec,crow.sysenv.jobs.JobRankSpec,
                  print_contents=True)
        can_hyper=self.hyperthreading_allowed
        max_per_node=self.cores_per_node
        if can_hyper and rank_spec.get('hyperthreading',False):
            max_per_node*=self.cpus_per_core
        threads_per_node=max_per_node
        omp_threads=max(1,rank_spec.get('OMP_NUM_THREADS',1))

        if omp_threads!=MAXIMUM_THREADS:
            max_per_node //= omp_threads

        max_ppn=rank_spec.get('max_ppn',0)
        if max_ppn:
            max_per_node=min(max_ppn,max_per_node)

        if max_per_node<1:
            raise MachineTooSmallError(f'Specification too large for node: max {threads_per_node} for {rank_spec!r}')
        return max_per_node

    def can_merge_ranks(self,R1,R2):
        return not R1['separate_node'] and not R2['separate_node'] and \
               R1['OMP_NUM_THREADS']==R2['OMP_NUM_THREADS'] and \
               R1.get('max_ppn',0)==R2.get('max_ppn',0) and \
               R1.get('exe','') == R2.get('exe','') and (
                 not self.hyperthreading_allowed or \
                 R1.get('hyperthreads',1) == R2.get('hyperthreads',1) )

    def same_except_exe(self,R1,R2):
        return not R1['separate_node'] and not R2['separate_node'] and \
               R1['OMP_NUM_THREADS']==R2['OMP_NUM_THREADS'] and \
               R1.get('max_ppn',0)==R2.get('max_ppn',0) and ( \
                 not self.hyperthreading_allowed or \
                 R1.get('hyperthreads',1) == R2.get('hyperthreads',1) )

    def node_size(self,rank_spec):
        typecheck('rank_spec',rank_spec,crow.sysenv.jobs.JobRankSpec)
        can_hyper=self.hyperthreading_allowed
        max_per_node=self.cores_per_node
        if can_hyper and rank_spec.get('hyperthreading',False):
            max_per_node*=self.cpus_per_core
        return max_per_node
