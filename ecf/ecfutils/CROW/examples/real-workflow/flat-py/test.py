#! /usr/bin/env python3.6

import subprocess
import shutil
import os
import logging
import sys
import glob
from copy import copy
import crow.config
import crow.sysenv

logging.basicConfig(stream=sys.stderr,level=logging.INFO)

logger=logging.getLogger('test')
conf=crow.config.from_file("flat.yaml")
par=crow.sysenv.get_parallelism('HydraIMPI',conf.parallelism)

assert(conf.clock is not None)

def rm(glob_me):
    for rm_me in glob.glob(glob_me):
        os.unlink(rm_me)

def namelist(content,filename):
    print(f'{filename} namelist:\n{content}\n')
    with open(filename,'wt') as fd:
        fd.write(content)

def run(what,check=True,**kwargs):
    j=crow.sysenv.JobResourceSpec(what)
    s=par.make_ShellCommand(j)
    return s.run(check=check,**kwargs)

for cycle in conf.clock:
    ymdh=cycle.strftime('%Y%m%d%H')
    logger.info(f'{ymdh}: start cycle')
    conf.clock.now=cycle

    crow.config.invalidate_cache(conf.options)
    com=conf.options.com
    logger.info(f'{ymdh} COM: {com}')
    assert(com)

    if os.path.exists(com): shutil.rmtree(com)
    os.makedirs(com)

    if cycle == conf.clock.start:
        logger.info(f'{ymdh}: first cycle: climatology initialization')
        namelist(conf.clim_init.namelist,'climatology_init.nl')
        run(conf.clim_init.resources)
        shutil.move(conf.clim_init.outfile,
                    os.path.join(com,"analysis.grid"))
    else:
        logger.info(f'{ymdh}: Run the ensemble, member-by-member.')
        for member_id in range(conf.options.ens_members+1): # 0..ens_members
            logger.info(f'{ymdh}: Run member {member_id}.')
            rm("output_*.grid")
            member=copy(conf.ens_fcst)
            member.member_id=member_id
            namelist(member.namelist,'forecast.nl')
            run(member.resources)
            shutil.move(member.ens_result,
                        conf.assimilate.member_input % member_id)
            rm("output_*.grid")
            
        logger.info(f'{ymdh}: assimilate data')
        namelist(conf.assimilate.namelist,'assimilate.nl')
        run(conf.assimilate.resources)
        shutil.move('analysis.grid',os.path.join(com,"analysis.grid"))
        
    logger.info(f'{ymdh}: Run the forecast for this cycle')
    rm("fcst_*.grid")
    namelist(conf.fcst.namelist,'forecast.nl')
    run(conf.fcst.resources)
    fcst_files = [ outfile for outfile in glob.glob("fcst_*.grid") ]
    for outfile in fcst_files:
        shutil.move(outfile,os.path.join(com,outfile))

    logger.info(f'{ymdh}: run the post for each output time.')
    for infile_base in fcst_files:
        outfile_base=infile_base.replace('fcst_','post_').replace('grid','txt')
        outfile=os.path.join(com,outfile_base)

        logger.info(f'{ymdh}: post {infile_base} => {outfile_base}')

        post=copy(conf.post)
        conf.post.infile=os.path.join(com,infile_base)

        namelist(conf.post.namelist,"post.nl")
        completed=run(conf.post.resources,
            stdout=subprocess.PIPE,encoding='ascii')

    logger.info(f'{ymdh}: cycle is complete.')

