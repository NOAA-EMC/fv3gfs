#! /usr/bin/env python3
f'This script requires Python 3.6 or newer.'

import os, io, sys
from crow.metascheduler import to_rocoto
from crow.config import from_dir, Suite

if len(sys.argv) != 2:
    sys.stderr.write('Syntax: make-ecflow-suite.py PSLOT\n')
    sys.stderr.write('PSLOT must match what you gave setup_expt.py\n')
    sys.exit(1)

conf=from_dir('.')
conf.sys_argv_1=sys.argv[1]
suite=Suite(conf.suite)
with open('workflow.xml','wt') as fd:
    print('workflow.xml')
    fd.write(to_rocoto(suite))
