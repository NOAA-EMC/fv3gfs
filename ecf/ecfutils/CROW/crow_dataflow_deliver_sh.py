#! /usr/bin/env python3.6

import sys, logging, shutil
from getopt import getopt
from contextlib import suppress
from crow.dataflow import Dataflow
from datetime import datetime
from crow.tools import shell_to_python_type

ALLOWED_DATE_FORMATS=[ '%Y-%m-%dt%H:%M:%S', '%Y-%m-%dT%H:%M:%S',
                       '%Y-%m-%d %H:%M:%S', '%Y%m%d%H', '%Y%m%d%H%M' ]

USAGE='''Format: crow_dataflow_sh.py [-v] [-m] ( -i input | -o output ) \\
  dataflow.db cycle actor var=value [var=value [...]]
  -c = just check for files; don't deliver them
  -m = expect multiple matches; -i or -o are formats instead of paths
  -v = verbose (set logging level to logging.DEBUG)
  -i input = local file to deliver to an output slot or "-" for stdin
  -o output = local file to receive data from an input slot or "-" for stdout
  dataflow.db = sqlite3 database file with state information
  cycle = forecast cycle in ISO format: 2019-08-15t13:08:14
  actor = actor (job) producing the data (period-separated: path.to.actor)
  slot=slotname = name of slot that produces or consumes the data
  var=type::value = specify type of value: int, float, bool, str
'''

def usage(why):
    sys.stderr.write(USAGE)
    sys.stderr.write(why+'\n')
    exit(1)

def deliver_by_name(logger,flow,local,message,check):
    logger.debug(f'{message.actor}.{message.slot} (meta={locals}): deliver by name from {local}')
    if check:
        strloc=local
        if local == '-' and flow=='O': strloc='(stdin)'
        if local == '-' and flow=='I': strloc='(stdout)'
        avail=message.availability_time()
        when='0'
        if avail:
            when=datetime.fromtimestamp(avail).strftime('%Y-%m-%dt%H:%M:%S')
        localmeta=message.get_meta()
        if localmeta:
            metas=[ f'{k}={v}' for k,v in localmeta.items() ]
            print(f'{bool(avail)} ({when}) - {message.flow} {message.actor} '
                  f'{message.slot} {" ".join(metas)}')
        else:
            print(f'{bool(avail)} ({when}) - {message.flow} {message.actor} '
                  f'{message.slot}')
    elif local != '-':
        if flow == 'O':
            message.deliver(local)
        else:
            message.obtain(local)
    elif flow=='I':
        with message.open('rb') as in_fd:
            shutil.copyfileobj(in_fd,sys.stdout.buffer)
    elif flow=='O':
        with message.open('wb') as out_fd:
            data=sys.stdin.buffer.read()
            logger.info(f'write {data}')
            #shutil.copyfileobj(sys.stdin.buffer,out_fd)
            out_fd.write(data)

def slot_meta_iter(slot,meta):
    for k,v in meta.items():
        if isinstance(v,list):
            for item in v:
                newmeta=dict(meta)
                newmeta[k]=item
                for s,m in slot_meta_iter(slot,newmeta):
                    yield s,m
            return
    yield slot,meta

def deliver_by_format(logger,flow,format,message,check):
    if "'''" in format:
        raise ValueError(f"{format}: cannot contain three single quotes "
                         "in a row '''")
    globals={ 'actor':message.actor, 'slot':message.slot, 'flow':message.flow, 
              'cycle':message.cycle }
    for slot,meta in slot_meta_iter(message,message.get_meta()):
        logger.debug(f'{message.actor}.{message.slot} (meta={meta}): filename format {format}')
        local_file=eval("f'''"+format+"'''",globals,meta)
        logger.debug(f'{message.actor}.{message.slot} (meta={meta}): deliver by format from {local_file}')
        deliver_by_name(logger,flow,local_file,message,check)

def has_meta_lists(slot):
    meta=slot.get_meta()
    for k,v in meta.items():
        if isinstance(v,list): return True
    return False

def main():
    (optval, args) = getopt(sys.argv[1:],'o:i:vmc')
    options=dict(optval)

    level=logging.DEBUG if '-v' in options else logging.INFO
    logging.basicConfig(stream=sys.stderr,level=level)
    logger=logging.getLogger('crow_dataflow_sh')

    if ( '-i' in options ) == ( '-o' in options ):
        usage('specify exactly one of -o and -i')

    flow = 'O' if '-i' in options else 'I'

    if len(args)<4:
        usage('specify dataflow db file, cycle, actor, and at least one var=value')

    ( dbfile, cyclestr, actor ) = args[0:3]
    cycle=None
    for fmt in ALLOWED_DATE_FORMATS:
        with suppress(ValueError):
            cycle=datetime.strptime(cyclestr,fmt)
            break
    if cycle is None: usage(f'unknown cycle format: {cyclestr}')

    slot=None
    meta={}
    for arg in args[3:]:
        split=arg.split('=',1)
        if len(split)!=2:
            usage(f'{arg}: arguments must be var=value')
        ( var, strvalue ) = split
        value=shell_to_python_type(strvalue)
        if var=='slot':
            slot=value
        elif var=='flow':
            usage(f'{arg}: cannot set flow; that is set automatically via -i or -o')
        elif var=='actor':
            usage(f'{arg}: cannot set actor; that is set via a positional argument')
        else:
            meta[var]=value

    db=Dataflow(dbfile)
    if flow=='I':
        logger.info(f'{dbfile}: find input slot actor={actor} slot={slot} '
                    f'meta={meta}')
        matches=iter(db.find_input_slot(actor,slot,meta))
        local=options['-o']
    else:
        logger.info(f'{dbfile}: find output slot actor={actor} slot={slot} '
                    f'meta={meta}')
        matches=iter(db.find_output_slot(actor,slot,meta))
        local=options['-i']

    slots = [ slot for slot in matches ]
    any_have_meta_lists=False
    for slot in slots:
        logger.info(str(slot))
        if has_meta_lists(slot):
            any_have_meta_lists=True
            logger.info('... has metadata lists')
    #any_have_meta_lists = any([ has_meta_lists(slot) for slot in slots ])
    multi = len(slots)>1 or any_have_meta_lists
   
    slot1, slot2 = None, None
    with suppress(StopIteration):
        slot1=next(matches)
        slot2=next(matches)

    if not slots:
        logger.error('No match for query.  Such a slot does not exist.')
        exit(1)
    elif multi and '-m' not in options:
        logger.error('Multiple matches, and -m not specified.  Abort.')
        exit(1)
    elif not multi and '-m' in options:
        logger.error('Single match but -m was specified.  Abort.')
        exit(1)

    for slot in slots:
        deliver_by_format(logger,flow,local,slot.at(cycle),'-c' in options)


if __name__ == '__main__':
    main()
