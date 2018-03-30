#! /usr/bin/env python3.6


import sys, logging, shutil
from getopt import getopt
from contextlib import suppress
from crow.dataflow import Dataflow
from datetime import datetime

ALLOWED_DATE_FORMATS=[ '%Y-%m-%dt%H:%M:%S', '%Y-%m-%dT%H:%M:%S',
                       '%Y-%m-%d %H:%M:%S', '%Y%m%d%H', '%Y%m%d%H%M' ]
def usage(why):
    sys.stderr.write('''Format: crow_dataflow_cycle_sh.py [-v] file.db (add|del) cycle
-v = be verbose
file.db = sqlite3 database with state information
add = start the cycle by copying template output records to cycle-specific ones
del = delete all output records for this cycle
cycle = cycle in posix format: YYYY-MM-DDtHH:MM:SS
''')
    sys.stderr.write(why+'\n')
    exit(1)

def main():
    (optval, args) = getopt(sys.argv[1:],'o:i:vm')
    options=dict(optval)

    level=logging.DEBUG if '-v' in options else logging.INFO
    logging.basicConfig(stream=sys.stderr,level=level)
    logger=logging.getLogger('crow_dataflow_sh')

    if len(args) != 3: usage("give exactly three non-option arguments")

    dbfile, adddel, cyclestr = args[0:3]
    if adddel not in [ 'add', 'del' ]:   usage('Specify "add" or "del"')

    cycle=None    
    for fmt in ALLOWED_DATE_FORMATS:
        with suppress(ValueError):
            cycle=datetime.strptime(cyclestr,fmt)
            break
    if cycle is None: usage(f'unknown cycle format: {cyclestr}')

    db=Dataflow(dbfile)
    logger.info(f'{dbfile}: {adddel} cycle {cycle:%Y-%m-%dt%H:%M:%S}')

    if adddel=='add': db.add_cycle(cycle)
    else:             db.del_cycle(cycle)

if __name__ == '__main__':
    main()
