#! /usr/bin/env python3
f'This script requires python 3.6 or later'

import unittest
from context import crow
from crow.sysenv import jobs
class TestBoth(unittest.TestCase):

    def setUp(self):
        inputData=[
            {'mpi_ranks':5, 'OMP_NUM_THREADS':12},
            {'mpi_ranks':7, 'OMP_NUM_THREADS':12},
            {'mpi_ranks':7} ]

        self.spec1=jobs.JobResourceSpec(inputData)

    def test_has_threads(self):
        self.assertTrue(self.spec1.has_threads())

    def test_num_ranks(self):
        self.assertEqual(self.spec1.total_ranks(), 19, 
                         'incorrect number of ranks')

    def test_pure_serial(self):
        self.assertFalse(self.spec1.is_pure_serial())

    def test_pure_openMP(self):
        self.assertFalse(self.spec1.is_pure_openmp())

    def test_spec_length(self):
        self.assertEqual(len(self.spec1),3)

    def test_is_mpi(self):
        for tspec in self.spec1:
            self.assertTrue(tspec.is_mpi())

    def test_openmp_true(self):
        for x in [0,1]:
            self.assertTrue(self.spec1[x].is_openmp())

    def test_openmp_false(self):
        self.assertFalse(self.spec1[2].is_openmp())

    def test_is_pure_serial(self):
        for tspec in self.spec1:
            self.assertFalse(tspec.is_pure_serial())


class TestSerial(unittest.TestCase):

    def setUp(self):
        inputData=[  { 'exe':'echo', 'args':['hello','world'] }  ]
        self.spec1=jobs.JobResourceSpec(inputData)

    def test_has_no_threads(self):
        self.assertFalse(self.spec1.has_threads())

    def test_total_ranks(self):
        self.assertEqual(self.spec1.total_ranks(), 0)

    def test_is_pure_serial(self):
        self.assertTrue(self.spec1.is_pure_serial())

    def test_is_not_pure_openmp(self):
        self.assertFalse(self.spec1.is_pure_openmp())

    def test_individual_spec_is_pure_serial(self):
        self.assertTrue(self.spec1[0].is_pure_serial())

    def test_individual_spec_is_not_openmp(self):
        self.assertFalse(self.spec1[0].is_openmp())

    def test_individual_spec_is_not_mpi(self):
        self.assertFalse(self.spec1[0].is_mpi())

class TestOpenMP(unittest.TestCase):

    def setUp(self):
        inputData=[ { 'OMP_NUM_THREADS':20 } ]
        self.spec1=jobs.JobResourceSpec(inputData)

    def test_has_threads(self):
        self.assertTrue(self.spec1.has_threads())

    def test_total_ranks(self):
        self.assertEqual(self.spec1.total_ranks(), 0)

    def test_is_not_pure_serial(self):
        self.assertFalse(self.spec1.is_pure_serial())

    def test_is_pure_openmp(self):
        self.assertTrue(self.spec1.is_pure_openmp())

    def test_individual_spec_is_not_pure_serial(self):
        self.assertFalse(self.spec1[0].is_pure_serial())

    def test_individual_spec_is_openmp(self):
        self.assertTrue(self.spec1[0].is_openmp())

    def test_individual_spec_is_not_mpi(self):
        self.assertFalse(self.spec1[0].is_mpi())

if __name__ == '__main__':
    unittest.main()
