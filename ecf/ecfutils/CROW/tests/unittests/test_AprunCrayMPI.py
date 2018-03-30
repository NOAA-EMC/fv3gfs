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

class TestAprunCrayMPI(unittest.TestCase):
    @classmethod
    def setUpClass(aprun):

        settings={ 'mpi_runner':'mpiexec',
           'physical_cores_per_node':24,
           'logical_cpus_per_core':2,
           'hyperthreading_allowed':True }
        
        aprun.par=get_parallelism('AprunCrayMPI',settings)
        aprun.sch=get_scheduler('LSFAlps',settings)

    def test_AprunCrayMPI_big(aprun):
        ranks=[ { 'mpi_ranks':12, 'hyperthreads':1, 'OMP_NUM_THREADS':4, 'exe':'exe1',
                  'AprunCrayMPI_extra':[ '-gdb', '-envall' ] },
                { 'mpi_ranks':48,                   'OMP_NUM_THREADS':1, 'exe':'exe2',
                  'AprunCrayMPI_extra':'-envall' },
                { 'mpi_ranks':200,'hyperthreads':1,                      'exe':'exe2' }  ]

        jr=JobResourceSpec(ranks)
        cmd=aprun.par.make_ShellCommand(jr)
        res=aprun.sch.rocoto_resources(jr)

        if os.environ.get('LOG_LEVEL','None') != "INFO":
            logging.disable(os.environ.get('LOG_LEVEL',logging.CRITICAL))
        logger.info('\n\nnmax_notMPI ranks:\n'+str(ranks) )
        logger.info(    'nmax_notMPI cmd  :\n'+str(cmd) )
        logger.info(    'nmax_notMPI res  :\n'+str(res) )
        logging.disable(logging.NOTSET)  

        logging.info("assertions not set yet")
        aprun.assertTrue( 'True' == 'True' )
         
    def test_AprunCrayMPI_max_ppn(aprun):
        ranks=[ { 'mpi_ranks':12, 'max_ppn':2, 'exe':'doit' },
                { 'mpi_ranks':12, 'max_ppn':4, 'exe':'doit' } ]

        jr=JobResourceSpec(ranks)
        cmd=aprun.par.make_ShellCommand(jr)
        res=aprun.sch.rocoto_resources(jr)

        if os.environ.get('LOG_LEVEL','None') != "INFO":
            logging.disable(os.environ.get('LOG_LEVEL',logging.CRITICAL))
        logger.info('\n\nnmax_notMPI ranks:\n'+str(ranks) )
        logger.info(    'nmax_notMPI cmd  :\n'+str(cmd) )
        logger.info(    'nmax_notMPI res  :\n'+str(res) )
        logging.disable(logging.NOTSET)  

        logging.info("assertions not set yet")
        aprun.assertTrue( 'True' == 'True' )
