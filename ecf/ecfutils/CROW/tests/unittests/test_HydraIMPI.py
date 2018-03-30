#! /usr/bin/env python3

import unittest, os, sys, logging

from context import crow

from crow import config
from crow import metascheduler
from crow.sysenv import JobResourceSpec
from crow.sysenv import get_parallelism
from crow.sysenv import get_scheduler

logging.basicConfig(stream=sys.stderr,level=logging.INFO)
logger = logging.getLogger()

class TestHydraIMPI(unittest.TestCase):
    @classmethod
    def setUpClass(hydra):

        settings={ 'mpi_runner':'mpiexec',
           'physical_cores_per_node':24,
           'logical_cpus_per_core':2,
           'hyperthreading_allowed':True }
        
        hydra.par=get_parallelism('HydraIMPI',settings)
        hydra.sch=get_scheduler('MoabTorque',settings)

    def test_HydraIMPI_big(hydra):
        ranks=[ { 'mpi_ranks':12, 'hyperthreads':1, 'OMP_NUM_THREADS':4, 'exe':'exe1',
                  'HydraIMPI_extra':[ '-gdb', '-envall' ] },
                { 'mpi_ranks':48,                   'OMP_NUM_THREADS':1, 'exe':'exe2',
                  'HydraIMPI_extra':'-envall' },
                { 'mpi_ranks':200,'hyperthreads':1,                      'exe':'exe2' }  ]

        jr=JobResourceSpec(ranks)
        cmd=hydra.par.make_ShellCommand(jr)
        res=hydra.sch.rocoto_resources(jr)

        if os.environ.get('LOG_LEVEL','None') != "INFO":
            logging.disable(os.environ.get('LOG_LEVEL',logging.CRITICAL))
        logger.info('\n\nbig ranks:\n'+str(ranks) )
        logger.info(    'big cmd  :\n'+str(cmd) )
        logger.info(    'big res  :\n'+str(res) )
        logging.disable(logging.NOTSET)

        hydra.assertTrue(str(cmd)=="ShellCommand(command=['mpiexec', '-gdb', '-envall', '-np', '12', '/usr/bin/env', 'OMP_NUM_THREADS=4', 'exe1', ':', '-envall', '-np', '48', '/usr/bin/env', 'OMP_NUM_THREADS=1', 'exe2', ':', '-np', '200', 'exe2'], env=None, cwd=None, files=[ ])")
        hydra.assertTrue(str(res)=='<nodes>2:ppn=6+2:ppn=24+2:ppn=23+7:ppn=22</nodes>\n')
         
    def test_HydraIMPI_max_ppn(hydra):
        ranks=[ { 'mpi_ranks':12, 'max_ppn':2, 'exe':'doit' },
                { 'mpi_ranks':12, 'max_ppn':4, 'exe':'doit' } ]

        jr=JobResourceSpec(ranks)
        cmd=hydra.par.make_ShellCommand(jr)
        res=hydra.sch.rocoto_resources(jr)

        if os.environ.get('LOG_LEVEL','None') != "INFO":
            logging.disable(os.environ.get('LOG_LEVEL',logging.CRITICAL))
        logger.info('\n\nnmax_notMPI ranks:\n'+str(ranks) )
        logger.info(    'nmax_notMPI cmd  :\n'+str(cmd) )
        logger.info(    'nmax_notMPI res  :\n'+str(res) )
        logging.disable(logging.NOTSET)

        hydra.assertTrue(str(cmd)=="ShellCommand(command=['mpiexec', '-np', '12', 'doit', ':', '-np', '12', 'doit'], env=None, cwd=None, files=[ ])")
        hydra.assertTrue(str(res)=='<nodes>6:ppn=2+3:ppn=4</nodes>\n')

    def test_HydraIMPI_max_notMPI(hydra):
        ranks=[ { 'OMP_NUM_THREADS':'max', 'exe':'exe1' } ]

        jr=crow.sysenv.JobResourceSpec(ranks)
        cmd=hydra.par.make_ShellCommand(jr)
        res=hydra.sch.rocoto_resources(jr)
   
        if os.environ.get('LOG_LEVEL','None') != "INFO":
            logging.disable(os.environ.get('LOG_LEVEL',logging.CRITICAL))
        logger.info('\n\nnmax_notMPI ranks:\n'+str(ranks) )
        logger.info(    'nmax_notMPI cmd  :\n'+str(cmd) )
        logger.info(    'nmax_notMPI res  :\n'+str(res) )
        logging.disable(logging.NOTSET)

        hydra.assertTrue(str(cmd)=="ShellCommand(command=['/bin/sh', '-c', 'exe1'], env={'OMP_NUM_THREADS': 24}, cwd=None, files=[ ])")
        hydra.assertTrue(str(res)=='<nodes>1:ppn=2</nodes>\n')

    def test_HydraIMPI_max_OMP_NUM_THREADS(hydra):
        ranks=[ { 'mpi_ranks':12, 'OMP_NUM_THREADS':'max', 'exe':'exe1', 'max_ppn':4 } ]

        jr=crow.sysenv.JobResourceSpec(ranks)
        cmd=hydra.par.make_ShellCommand(jr)
        res=hydra.sch.rocoto_resources(jr)

        if os.environ.get('LOG_LEVEL','None') != "INFO":
            logging.disable(os.environ.get('LOG_LEVEL',logging.CRITICAL))
        logger.info('\n\nnmax_OMP ranks:\n'+str(ranks) )
        logger.info (    'nmax_OMP cmd  :\n'+str(cmd) )
        logger.info (    'nmax_OMP res  :\n'+str(res) )
        logging.disable(logging.NOTSET)

        hydra.assertTrue(str(cmd)=="ShellCommand(command=['mpiexec', '-np', '12', '/usr/bin/env', 'OMP_NUM_THREADS=6', 'exe1'], env=None, cwd=None, files=[ ])")
        hydra.assertTrue(str(res)=='<nodes>3:ppn=4</nodes>\n')
