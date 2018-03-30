import sys
from abc import abstractmethod
from collections import UserList, Mapping, Sequence, OrderedDict
from subprocess import Popen, PIPE, CompletedProcess
from crow.sysenv.exceptions import InvalidJobResourceSpec

__all__=['JobRankSpec','JobResourceSpec']

JOB_RANK_SPEC_TEMPLATE={
    'mpi_ranks':0,
    'OMP_NUM_THREADS':0,
    'hyperthreading':False }

MISSING=object() # special constant for missing arguments

MAXIMUM_THREADS=sys.maxsize

########################################################################

class JobRankSpec(Mapping):
    OPTIONAL_ATTRIBUTES=[
        'walltime', 'memory', 'outer', 'stdout', 'stderr', 'jobname',
        'batch_memory', 'compute_memory' ]

    def __init__(self,OMP_NUM_THREADS=0,mpi_ranks=0,
                 exe=MISSING,args=MISSING,exclusive=True,
                 separate_node=False,hyperthreads=1,max_ppn=MISSING,
                 **kwargs):
        if OMP_NUM_THREADS is None: OMP_NUM_THREADS=0
        if mpi_ranks is None:       mpi_ranks=0
        if args is None:            args=MISSING
        if exclusive is None:       exclusive=True
        if hyperthreads is None:    hyperthreads=1
        if max_ppn is None:         max_ppn=MISSING
        if OMP_NUM_THREADS == 'max':
            OMP_NUM_THREADS=MAXIMUM_THREADS
        self.__spec={
            'mpi_ranks':max(0,int(mpi_ranks)),
            'exclusive':bool(exclusive),
            'separate_node':separate_node,
            'hyperthreads':int(hyperthreads),
            'OMP_NUM_THREADS':max(0,int(OMP_NUM_THREADS)),
            'exe':( None if exe is MISSING else exe ),
            'args':( [] if args is MISSING else list(args) ) }

        if max_ppn is not MISSING:
            self.__spec['max_ppn']=int(max_ppn)

        for key,value in kwargs.items():
            if not key in JobRankSpec.OPTIONAL_ATTRIBUTES \
                    and not key.endswith('_extra'):
                raise TypeError(f'Unknown argument {key}')
            self.__spec[key]=value

        if not isinstance(exe,str) and exe is not MISSING and \
           exe is not None:
            raise TypeError('exe must be a string, not a %s'%(
                type(exe).__name__,))

    def getexe(self): return self.__spec['exe']
    exe=property(getexe,None,None,None)

    def is_exclusive(self):
        """!Trinary accessor - True, False, None (unset).  None indicates 
        no request was made for or against exclusive."""
        return self.__spec['exclusive']

    def is_pure_serial(self):
        return not self.is_mpi() and not self.is_openmp()
    def want_max_threads(self):
        return self['OMP_NUM_THREADS']==MAXIMUM_THREADS

    def is_openmp(self):      return self['OMP_NUM_THREADS']>0
    def is_mpi(self):         return self['mpi_ranks']>0

    def simplify(self,adapt):
        js=JobRankSpec(**self.__spec)
        adapt(js.__spec)
        return js

    def new_with(self,*args,**kwargs):
        """!Creates a new JobRankSpec with the given modifications.  The
        calling convention is the same as dict.update()."""
        newspec=dict(self.__spec)
        newspec.update(*args,**kwargs)
        return JobRankSpec(**newspec)

    # Nicities
    def __getattr__(self,key):    return self[key]

    # Implement Mapping abstract methods:
    def __getitem__(self,key):    return self.__spec[key]
    def __len__(self):            return len(self.__spec)
    def __contains__(self,key):   return key in self.__spec
    def __iter__(self):
        for k in self.__spec:
            yield k
    def __repr__(self):
        typ=type(self).__name__
        return typ+'{'+\
            ','.join([f'{repr(k)}:{repr(v)}' for k,v in self.items()]) + \
            '}'

########################################################################

class JobResourceSpec(Sequence):
    def __init__(self,specs):
        try:
            self.__specs=[ JobRankSpec(**spec) for spec in specs ]
        except(ValueError,TypeError,IndexError) as e:
            raise InvalidJobResourceSpec("Invalid resource specification:"+
                                      repr(specs))

    # Implement Sequence abstract methods:
    def __getitem__(self,index): return self.__specs[index]
    def __len__(self):           return len(self.__specs)

    def simplify(self,adapt_resource_spec,adapt_rank_spec):
        new=JobResourceSpec(
            [ spec.simplify(adapt_rank_spec) for spec in self ])
        adapt_resource_spec(new.__specs)
        return new

    def has_threads(self):
        return any([ spec.is_openmp() for spec in self])

    def total_ranks(self):
        return sum([ spec['mpi_ranks'] for spec in self])

    def is_pure_serial(self):
        return len(self)<2 and self[0].is_pure_serial()

    def is_pure_openmp(self):
        return len(self)<2 and not self[0].is_mpi() and self[0].is_openmp()

    def __repr__(self):
        typ=type(self).__name__
        return f'{typ}[{", ".join([repr(r) for r in self])}]'

########################################################################
 

def test():
    # MPI + OpenMP program test
    input1=[
        {'mpi_ranks':5, 'OMP_NUM_THREADS':12},
        {'mpi_ranks':7, 'OMP_NUM_THREADS':12},
        {'mpi_ranks':7} ]
    spec1=JobResourceSpec(input1)
    assert(spec1.has_threads())
    assert(spec1.total_ranks()==19)
    assert(not spec1.is_pure_serial())
    assert(not spec1.is_pure_openmp())
    assert(len(spec1)==3)
    for x in [0,1,2]:
        assert(spec1[x].is_mpi())
    for x in [0,1]:
        assert(spec1[x].is_openmp())
    assert(not spec1[2].is_openmp())
    for x in [0,1,2]:
        assert(not spec1[x].is_pure_serial())

    # Serial program test
    input2=[ { 'exe':'echo', 'args':['hello','world'] } ]
    spec2=JobResourceSpec(input2)
    assert(not spec2.has_threads())
    assert(spec2.total_ranks()==0)
    assert(spec2.is_pure_serial())
    assert(not spec2.is_pure_openmp())
    assert(spec2[0].is_pure_serial())
    assert(not spec2[0].is_openmp())
    assert(not spec2[0].is_mpi())

    # Pure openmp test
    input3=[ { 'OMP_NUM_THREADS':20 } ]
    spec3=JobResourceSpec(input3)
    assert(spec3.has_threads())
    assert(spec3.total_ranks()==0)
    assert(not spec3.is_pure_serial())
    assert(spec3.is_pure_openmp())
    assert(not spec3[0].is_pure_serial())
    assert(spec3[0].is_openmp())
    assert(not spec3[0].is_mpi())
