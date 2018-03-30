#! /usr/bin/env python3.6

import unittest
from context import crow
import crow.config
from datetime import timedelta, date, datetime
from collections import OrderedDict


class TestExampleConfig(unittest.TestCase):

    def setUp(self):
        self.config=crow.config.from_file('../test_data/toy-yaml/test.yml',
                                          '../test_data/toy-yaml/platform.yml',
                                          '../test_data/toy-yaml/templates.yml',
                                          '../test_data/toy-yaml/actions.yml')
        crow.config.validate(self.config.fcst)
        crow.config.validate(self.config.test)
        crow.config.validate(self.config.gfsfcst)

    def test_not_working(self):
        self.assertTrue(True)

    def test_ordered_dict(self):
        self.assertEqual(self.config.ordered_dict, \
              OrderedDict({('one',1), ('two',2), ('three',3), ('four',4), 
                                                              ('five',5)}))

    def test_set(self):
        self.assertEqual(self.config.set, set((2, date(2017, 8, 15), 'a')))

    def test_bool_array(self):
        self.assertEqual(self.config.fcst.bool_array, [True, False, True]) 

    def test_int_array(self):
        self.assertEqual(self.config.fcst.int_array, [1, 2, 3, 4, 5]) 

    def test_string_array(self):
        self.assertEqual(self.config.fcst.string_array, ['a', 'b', 'c', 'd',
                                                                        'e']) 

    def test_plus(self):
        self.assertEqual(self.config.gfsfcst.a, 10)

    def test_FirstMax(self):
        self.assertEqual(self.config.gfsfcst.d, 9200)

    def test_calclist(self):
        self.assertEqual(self.config.gfsfcst.stuff[0], 30)

    def test_default(self):
        self.assertEqual(self.config.gfsfcst.cow, 'blue')
        self.assertEqual(self.config.gfsfcst.dog, 'brown')

    def test_strlen_func(self):
        self.assertEqual(self.config.gfsfcst.lencow, 4)

    def test_FirstTrue(self):
        self.assertEqual(self.config.test.B, 'B')

    def test_LastTrue(self):
        self.assertEqual(self.config.test.C, 'C')

    def test_NoneTrue(self):
        self.assertIsNone(self.config.test.none)

    def test_conditionals_on_empty_list(self):
        for bad in ['lt', 'ft', 'xv', 'nv']:
            self.assertIsNone(self.config.test['bad' + bad])

    def test_time_values(self):
        self.assertEqual(self.config.test.dt, timedelta(0, 12000))
        self.assertEqual(self.config.test.fcsttime, datetime(2017, 9, 19, 21, 20))
        self.assertEqual(self.config.test.fYMDH, '2017091921')

    def test_string_expansion(self):
        self.assertEqual(self.config.test.expandme, 'abc, def, ghi')

    def test_fcst_values(self):
        self.assertEqual(self.config.fcst.hydro_mono, 'hydro_mono')

    def test_inline_namelist(self):
        namelist_for_test = self.config.fcst.some_namelist
        cmpline=["&some_namelist", "  int_array = 1, 2, 3, 4, 5", 
                 "  bool_array = .True., .False., .True.", 
                 "  string_array = 'a', 'b', 'c', 'd', 'e'", 
                 "  type = 'hydro'", "  mono = 'mono'", 
                 "  shal_cnv = .True.", "  agrid_vel_rst= .True.", 
                 "/", ""]
        for lnum, line in enumerate(namelist_for_test.split('\n')):
            #print("\nline   XXX"+line+"XXX")
            #print("cmplineXXX"+cmpline[lnum]+"XXX")
            self.assertEqual(line,cmpline[lnum],
                             "line {} not equal to expected {} in \
                              namelist".format(line, cmpline[lnum]))

    def test_file_namelist(self):
        with open('../test_data/toy-yaml/namelist.nl','rt') as fd:
            namelist_nl=fd.read()

        namelist2_for_test = crow.config.expand_text(namelist_nl,self.config.fcst)

        cmpline=["&some_namelist", "  int_array = 1, 2, 3, 4, 5", 
                 "  bool_array = .True., .False., .True.", 
                 "  string_array = 'a', 'b', 'c', 'd', 'e'", 
                 "  type = 'hydro'", "  mono = 'mono'", 
                 "  shal_cnv = .True.", "  agrid_vel_rst= .True.", 
                 "/", ""]
        for lnum, line in enumerate(namelist2_for_test.split('\n')):
            #print("\nline   XXX"+line+"XXX")
            #print("cmplineXXX"+cmpline[lnum]+"XXX")
            self.assertEqual(line,cmpline[lnum],
                             "line {} not equal to expected {} in \
                              namelist".format(line, cmpline[lnum]))

    def test_error_clause(self):
        try:
            s=self.config.test.error
            self.assertTrue(False, "Failed to process error clause properly.")
        except crow.config.ConfigUserError as e:
            self.assertTrue(True)

    def test_msg_clause(self):
        self.assertEqual(self.config.test.message,'hello')

    def test_inherit(self):
        crow.config.validate(self.config.fancy_fcst)
        self.assertEqual(self.config.fancy_fcst.stuff[0], 30)
        self.assertEqual(self.config.fancy_fcst.fancy_var, 5)
        self.assertNotIn('not_fancy', self.config.fancy_fcst)
        

if __name__ == '__main__':
    unittest.main()
