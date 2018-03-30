#! /usr/bin/env python3.6
import logging, sys
from getopt import getopt
from crow.dataflow import Dataflow
from crow.tools import shell_to_python_type

def usage(why):
    sys.stderr.write('''Format: crow_dataflow_find_sh.py [-v] (I|O) [ search parameters ]
 -v = verbose
 I = input slot
 O = output slot
 actor=path.to.actor = actor producing or consuming data
 slot=slot_name = name of input or output slot
 other=other = slot property\n''')
    sys.stderr.write(why+'\n')
    exit(1)

def main():
    (optval,args) = getopt(sys.argv[1:],'v')
    options=dict(optval)
    if len(args)<2:
        usage('specify database file and flow')

    level=logging.DEBUG if '-v' in options else logging.INFO
    logging.basicConfig(stream=sys.stderr,level=level)
    logger=logging.getLogger('crow_dataflow_sh')

    logger.info('top of script')

    dbfile, flow = args[0:2]

    if flow not in 'OI':
        usage(f"flow must be O (output) or I (input) not {flow}")

    primary={ 'flow':flow, 'actor':None, 'slot':None }
    meta={}
    for arg in args[2:]:
        split=arg.split('=',1)
        if len(split)!=2:
            usage(f'{arg}: arguments must be var=value')
        ( var, strvalue ) = split
        value=shell_to_python_type(strvalue)
        if var in primary:
            primary[var]=value
        else:
            meta[var]=value

    logger.info(f'{dbfile}: open sqlite3 database')
    db=Dataflow(dbfile)
    if flow == 'O':
        find=db.find_output_slot
        message='find output slots'
    else:
        find=db.find_input_slot
        message='find input slots'

    if primary['actor']:
        message+=f' actor={primary["actor"]}'
    else:
        message+=' for all actors'
    if primary['slot']: message+=f' slot={primary["slot"]}'
    if meta:
        message+=' meta: '
        for k,v in meta:
            message+=f' {k}={v}'

    logger.info(message)
    db.dump(sys.stderr)
    for slot in find(primary['actor'],primary['slot'],meta):
        localmeta=slot.get_meta()
        sys.stderr.write(f'{slot} meta = {localmeta}\n')
        if localmeta:
            metas=[ f'{k}={v}' for k,v in localmeta.items() ]
            print(f'{slot.flow} {slot.actor} {slot.slot} {" ".join(metas)}')
        else:
            print(f'{slot.flow} {slot.actor} {slot.slot}')

if __name__ == '__main__':
    main()
