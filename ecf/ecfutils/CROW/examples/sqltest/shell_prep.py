#! /usr/bin/env python3.6
import logging, os, sys, shutil
from datetime import datetime, timedelta
from crow.dataflow import Dataflow

SIX_HOURS=timedelta(seconds=3600*6)

def main():
    logging.basicConfig(stream=sys.stderr,level=logging.DEBUG)

    if os.path.exists('test.db'):
        os.unlink('test.db')
    if os.path.exists('com'):
        shutil.rmtree('com')

    d=Dataflow('test.db')
    
    PRE='com/{cycle:%Y%m%d%H}/{actor}/{slot}.t{cycle:%H}z'
    d.add_output_slot('fam.job1','oslot',PRE+'.x')
    d.add_input_slot('fam.job2','islot')
    d.add_input_slot('fam.job2','tslot',{
        'when':datetime.now(), 'why':True })

    for S in [1,2,3]:
        for L in 'AB':
            d.add_output_slot('fam.job2','oslot',PRE+'.{letter}{slotnum}',
                              {'slotnum':S, 'letter':L})

    for S in [1,2,3]:
        for L in 'AB':
            d.add_input_slot('fam.job3','islot',{'plopnum':S, 'letter':L})

    for islot in d.find_input_slot('fam.job2','tslot'):
        for oslot in d.find_output_slot('fam.job1','oslot'):
            islot.connect_to(oslot,rel_time=SIX_HOURS)

    for islot in d.find_input_slot('fam.job3','islot'):
        meta=islot.get_meta()
        found=False
        for oslot in d.find_output_slot('fam.job2','oslot',{
                'slotnum':meta['plopnum'], 'letter':meta['letter'] }):
            islot.connect_to(oslot,rel_time=SIX_HOURS)

if __name__ == '__main__': 
    main()
