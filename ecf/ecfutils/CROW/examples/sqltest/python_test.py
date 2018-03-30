#! /usr/bin/env python3.6
import logging, os, sys, shutil
from datetime import datetime, timedelta
from crow.dataflow import Dataflow

def deliver_cycle(d: Dataflow, cycle: datetime) -> None:
    text=f'dummy file for cycle {cycle:%Y%m%d%H}\n'

    for oslot in d.find_output_slot('fam.job2','oslot',{'letter':'A'}):
        omessage=oslot.at(cycle)
        with open('dummy_file','wt') as fd1:
            fd1.write(str(omessage))
        omessage.deliver('dummy_file')

    for oslot in d.find_output_slot('fam.job2','oslot',{'letter':'B'}):
        omessage=oslot.at(cycle)
        with omessage.open('wt') as fd2:
            fd2.write(str(omessage))

    if os.path.exists('dummy_file'): os.unlink('dummy_file')

def check_cycle(d: Dataflow, cycle: datetime) -> None:
    for islot in d.find_input_slot('fam.job3','islot',{'letter':'A'}):
        imessage=islot.at(cycle)
        with imessage.open('rt') as fd:
            print(f"{fd.readline().strip()}: {imessage}")

    for islot in d.find_input_slot('fam.job3','islot',{'letter':'B'}):
        imessage=islot.at(cycle)
        imessage.obtain('dummy_input')
        with open('dummy_input','rt') as fd:
            print(f"{fd.readline().strip()}: {imessage}")

def main():
    logging.basicConfig(stream=sys.stderr,level=logging.INFO)

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
    d.dump(sys.stdout)
    six_hours=timedelta(seconds=3600*6)
    for islot in d.find_input_slot('fam.job3','islot'):
        meta=islot.get_meta()
        print(meta)
        found=False
        for oslot in d.find_output_slot('fam.job2','oslot',{
                'slotnum':meta['plopnum'], 'letter':meta['letter'] }):
            islot.connect_to(oslot,rel_time=six_hours)
            break

    cycle1=datetime.strptime('2017081500','%Y%m%d%H')
    cycle2=datetime.strptime('2017081506','%Y%m%d%H')
    cycle3=datetime.strptime('2017081512','%Y%m%d%H')

    d.add_cycle(cycle1)
    d.add_cycle(cycle2)
    deliver_cycle(d,cycle1)
    check_cycle(d,cycle2)

    d.add_cycle(cycle3)
    d.del_cycle(cycle1)
    deliver_cycle(d,cycle2)
    check_cycle(d,cycle3)


if __name__=='__main__':
    main()
