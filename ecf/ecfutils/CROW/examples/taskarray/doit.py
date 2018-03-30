#! /usr/bin/env python3
f'This script requires Python 3.6 or newer.'

import os
from crow.metascheduler import to_ecflow
from crow.config import from_file, Suite

conf=from_file('taskarray.yaml')
suite=Suite(conf.suite)
suite_defs, ecf_files = to_ecflow(suite)

for defname in suite_defs:
    #print(f'=== contents of suite def {defname}\n{suite_defs[defname]}')
    filename=defname
    print(filename)
    dirname=os.path.dirname(filename)
    if dirname and not os.path.exists(dirname):
        os.makedirs(os.path.dirname(filename))
    with open(filename,'wt') as fd:
        fd.write(suite_defs[defname]['def'])

for setname in ecf_files:
    print(f'ecf file set {setname}:\n')
    for filename in ecf_files[setname]:
        print(f'  file {filename}')
        dirname=os.path.dirname(filename)
        if dirname and not os.path.exists(dirname):
            os.makedirs(os.path.dirname(filename))
        with open(filename+".ecf",'wt') as fd:
            fd.write(ecf_files[setname][filename])
        
        #for line in ecf_files[setname][filename].splitlines():
            #print(f'    {line.rstrip()}')

