#! /usr/bin/env python3
f'This script requires python 3.6 or later'

import unittest
from context import crow
from crow.sysenv.util import ranks_to_nodes_ppn

class TestRankstoNodes(unittest.TestCase):

    def test_10_109(self):
        self.assertEqual([(10, 10),(1, 9)], ranks_to_nodes_ppn(10, 109))

    def test_3_10(self):
        self.assertEqual([(2, 3),(2, 2)], ranks_to_nodes_ppn(3, 10))

    def test_10_3(self):
        self.assertEqual([(1, 3)], ranks_to_nodes_ppn(10, 3))

    def test_24_31(self):
        self.assertEqual([(1, 16),(1, 15)], ranks_to_nodes_ppn(24, 31))

    def test_24_62(self):
        self.assertEqual([(2, 21),(1, 20)], ranks_to_nodes_ppn(24, 62))


    def test_10_109(self):
        self.assertEqual([(10, 10),(1, 9)], ranks_to_nodes_ppn(10, 109))

if __name__ == '__main__':
    unittest.main()
