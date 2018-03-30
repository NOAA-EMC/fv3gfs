#! /usr/bin/env python3.6

import sys, os, logging, subprocess

import crow
import crow.config
import crow.metascheduler
import crow.sysenv

logging.basicConfig(stream=sys.stderr,level=logging.INFO)

settings={ 'mpi_runner':'mpiexec',
           'physical_cores_per_node':24,
           'logical_cpus_per_core':2,
           'hyperthreading_allowed':True }

par=crow.sysenv.get_parallelism('HydraIMPI',settings)
sch=crow.sysenv.get_scheduler('MoabTorque',settings)

########################################################################
# Test 1: big, fancy command:
ranks=[ 
    { 'mpi_ranks':12, 'hyperthreads':1, 'OMP_NUM_THREADS':4, 'exe':'exe1',
      'HydraIMPI_extra':[ '-gdb', '-envall' ] },
    { 'mpi_ranks':48,                   'OMP_NUM_THREADS':1, 'exe':'exe2',
      'HydraIMPI_extra':'-envall' },
    { 'mpi_ranks':200,'hyperthreads':1,                      'exe':'exe2' }
    ]
jr=crow.sysenv.JobResourceSpec(ranks)
cmd=par.make_ShellCommand(jr)
res=sch.rocoto_resources(jr)
print(str(ranks))
print('becomes')
print(str(cmd))
print(str(res))
assert(str(cmd)=="ShellCommand(command=['mpiexec', '-gdb', '-envall', '-np', '12', '/usr/bin/env', 'OMP_NUM_THREADS=4', 'exe1', ':', '-envall', '-np', '48', '/usr/bin/env', 'OMP_NUM_THREADS=1', 'exe2', ':', '-np', '200', 'exe2'], env=None, cwd=None, files=[ ])")
assert(str(res)=='<nodes>2:ppn=6+2:ppn=24+2:ppn=23+7:ppn=22</nodes>\n')

########################################################################
# Test 2: hard-coded max_ppn:

ranks=[ { 'mpi_ranks':12, 'max_ppn':2, 'exe':'doit' },
        { 'mpi_ranks':12, 'max_ppn':4, 'exe':'doit' } ]

jr=crow.sysenv.JobResourceSpec(ranks)
cmd=par.make_ShellCommand(jr)
res=sch.rocoto_resources(jr)
print(str(ranks))
print('becomes')
print(str(cmd))
print(str(res))
assert(str(cmd)=="ShellCommand(command=['mpiexec', '-np', '12', 'doit', ':', '-np', '12', 'doit'], env=None, cwd=None, files=[ ])")
assert(str(res)=='<nodes>6:ppn=2+3:ppn=4</nodes>\n')

########################################################################

if os.path.exists('file1'): os.unlink('file1')
if os.path.exists('file2'): os.unlink('file2')

cmd=crow.sysenv.ShellCommand(['/bin/sh','-c', 'cat $FILE1 $FILE2'],
      files=[ { 'name':'file1', 'content':'hello ' }, 
              { 'name':'file2', 'content':'world\n' } ],
      env={ 'FILE1':'file1', 'FILE2':'file2' },
      cwd='.' )
result=cmd.run(stdout=subprocess.PIPE,encoding='ascii')
print(repr(result.stdout))
assert(result.stdout=='hello world\n')

if os.path.exists('file1'): os.unlink('file1')
if os.path.exists('file2'): os.unlink('file2')

#config=crow.config.from_file(
#    'platform.yml','templates.yml','actions.yml','workflow.yml')

#print(crow.met.Sascheduler.to_rocoto(config.my_fancy_workflow))
