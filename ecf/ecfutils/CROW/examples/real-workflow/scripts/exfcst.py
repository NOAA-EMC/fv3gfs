#! /usr/bin/env python3.6

from trace import Trace

def main():
    import os
    import sys
    import logging
    import shutil
    import glob
    import datetime
    import crow.config
    import crow.sysenv
    from copy import copy

    logging.basicConfig(stream=sys.stderr,level=logging.INFO,
       format='%(module)s:%(lineno)d: %(levelname)8s: %(message)s')
    logger=logging.getLogger('exfcst')

    logger.info(f"{os.environ['CONFIG_YAML']}: read")
    conf=crow.config.from_file(os.environ['CONFIG_YAML'])
    conf.clock.now=datetime.datetime.strptime(os.environ['YMDH'],'%Y%m%d%H')
    runner=conf.platform.parallelism
    scope_name=sys.argv[1]
    logger.info(f'{scope_name}: forecast in this scope')
    scope=conf[scope_name]
    
    def run_fcst(action):
        namelist=action.namelist
        with open('forecast.nl','wt') as fd:
            fd.write(namelist)
        runner.run(action.resources,check=True)
    
    if len(sys.argv)>=3:
        start_member=int(sys.argv[2],10)
        stop_member=int(sys.argv[3],10)
        logger.info(f'Run ensemble members {start_member} to {stop_member}')
        member_id=start_member
        while member_id<=stop_member:
            fcst=copy(scope)
            fcst.member_id=member_id
            logger.info(f'Member {fcst.member_id}')
            run_fcst(fcst)
            result=fcst.ens_output
            comfile=os.path.join(fcst.com,fcst.ens_com_filename)
            shutil.copy2(result,comfile)
            member_id+=1
    else:
        run_fcst(scope)
        for filename in glob.glob(scope.copy_glob):
            shutil.copy2(filename,conf.runtime.com)

if __name__=='__main__':
    import sys
    import yaml
    import crow
    main()
#    Trace(ignoredirs=[sys.prefix,sys.exec_prefix],
#          ignoremods=('crow','yaml','crow.config','crow.config.eval_tools'),timing=1).run("main()")
