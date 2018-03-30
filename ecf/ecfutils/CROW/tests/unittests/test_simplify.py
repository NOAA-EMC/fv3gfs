#! /usr/bin/env python3
f'This script requires python 3.6 or later'

import unittest
from context import crow
from crow.metascheduler.simplify import *
import crow.config
from datetime import timedelta
from crow.config import OrDependency,AndDependency,NotDependency, \
    TRUE_DEPENDENCY, FALSE_DEPENDENCY, LogicalDependency


class TestSimplify(unittest.TestCase):

    def setUp(self):
        self.DEP1=crow.config.CycleExistsDependency(timedelta())
        self.DEP2=crow.config.CycleExistsDependency(timedelta(seconds=3600))
        self.DEP3=crow.config.CycleExistsDependency(timedelta(seconds=7200))
        self.DEP4=crow.config.CycleExistsDependency(timedelta(seconds=10800))


    def test_comp_or(self):
        self.assertAlmostEqual(complexity(self.DEP1|self.DEP2), 2.4, places=3)

    def test_comp_and(self):
        self.assertAlmostEqual(complexity(self.DEP1&self.DEP2), 2.4, places=3)

    def test_comp_nand(self):
        self.assertAlmostEqual(complexity(~(self.DEP1&self.DEP2)), 2.88, places=3)

    def test_simp_a_or_not_a(self):
        self.assertEqual(simplify(~self.DEP1 | self.DEP1), TRUE_DEPENDENCY)

    def test_simp_a_and_not_a(self):
        self.assertEqual(simplify(~self.DEP1 & self.DEP1), FALSE_DEPENDENCY)

    def test_simp_not_not_a_or_not_b(self):
        self.assertEqual(simplify(~(~self.DEP1 | ~self.DEP2)), self.DEP1 & self.DEP2)

    def test_simp_gobbledygook(self):
        self.assertEqual(simplify(~self.DEP2 & ~(~self.DEP1 | ~self.DEP2)), FALSE_DEPENDENCY)

    def test_simp_extended_expr(self):
        self.assertEqual(simplify((self.DEP1 | self.DEP2 | self.DEP4) & \
                         (self.DEP1 | self.DEP3 | self.DEP4)), \
                           self.DEP1 | self.DEP2 & self.DEP3 | self.DEP4)
if __name__ == '__main__':
    unittest.main()
