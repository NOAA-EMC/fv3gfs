#! /usr/bin/env python3.6

def main():

    import os, datetime, shutil
    import crow.config
    import crow.sysenv

    conf=crow.config.from_file(os.environ['CONFIG_YAML'])
    conf.clock.now=datetime.datetime.strptime(os.environ['YMDH'],'%Y%m%d%H')
    runner=conf.platform.parallelism
    namelist=conf.clim_init.namelist
    with open('climatology_init.nl','wt') as fd:
        fd.write(namelist)
    cmd=runner.run(conf.clim_init.resources,check=True)
    shutil.copy2(conf.clim_init.outfile,conf.runtime.com)

if __name__=='__main__':
    import trace, sys
    tracer=trace.Trace(ignoredirs=[sys.prefix,sys.exec_prefix],
                       ignoremods=['yaml','eval_tools','from_yaml','to_yaml'],
                       timing=1)
    tracer.run('main()')
