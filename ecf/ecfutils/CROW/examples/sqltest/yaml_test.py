#! /usr/bin/env python3
f'This script requires Python 3.6 or later'
import os, sys
import crow.config
import crow.dataflow

if os.path.exists('test.db'):
    os.unlink('test.db')

conf=crow.config.from_file('test.yaml')
suite=crow.config.Suite(conf.suite)

print('DUMP SLOT DATA FROM SUITE')
for item in suite.walk_task_tree():
    if item.is_output_slot():
        print(f'{item.path}: output slot')
        for slot in item.slot_iter():
            print(f'  --> {slot}')
    elif item.is_input_slot():
        print(f'{item.path}: input slot')
        for slot in item.slot_iter():
            print(f'  --> input: {slot}')
            print(f'  --> output: {slot.Out}')
    else:
        print(f'{item.path}: {type(item).__name__}')
print('-'*72)
print('DUMP SLOT DATA FROM DATAFLOW')
df=crow.dataflow.from_suite(suite,'test.b')
df.dump(sys.stdout)
