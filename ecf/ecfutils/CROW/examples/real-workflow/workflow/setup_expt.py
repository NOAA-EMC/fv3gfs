#! /usr/bin/env python3.6

import os, sys, logging
import crow.config
from crow.config import Platform
import crow.metascheduler

logging.basicConfig(stream=sys.stderr,level=logging.INFO,
   format='%(module)s:%(lineno)d: %(levelname)8s: %(message)s')
logger=logging.getLogger('setup_expt')

conf=crow.config.from_file(
    'platform.yaml','options.yaml','runtime.yaml',
    'actions.yaml','workflow.yaml')

force = len(sys.argv)>1 and sys.argv[1] == '--force'

logger.info('Remove platforms from configuration.')
for key in list(conf.keys()):
    if isinstance(conf[key],Platform) and key!='platform':
        del conf[key]

run_dir=conf.options.run_dir
logger.info(f'Run directory: {run_dir}')

assert('namelist' in conf.generic_fcst)
assert('namelist' in conf.fcst)
assert('namelist' in conf.ens_fcst)

try:
    os.makedirs(run_dir)
except FileExistsError:
    logger.warning(f'{run_dir}: exists')
    if not force:
        logger.error(f'{run_dir}: already exists.  Delete or use --force.')
        sys.exit(1)
    logger.warning(f'--force given; will replace config.yaml without '
                   'deleting directory')

expname=conf.options.experiment_name
logger.info(f'Experiment name: {expname}')

suite, rocoto_xml=crow.metascheduler.to_rocoto(conf.workflow)

assert('testvar' in suite.cycled_init.ensemble.ens_fcst_000_020.Perform)

# Get the root of the newly-parsed document:
doc=crow.config.document_root(suite)

assert('testvar' in doc.workflow.cycled_init.ensemble.ens_fcst_000_020.Perform)
print(doc.workflow.cycled_init.ensemble.ens_fcst_000_020.Perform.testvar)

config_yaml=os.path.join(run_dir,'config.yaml')
yaml=crow.config.to_yaml(doc)

logger.info(f'Write the config file: {config_yaml}')
with open(config_yaml,'wt') as fd:
    fd.write(yaml)

rocoto_xml_file=os.path.join(run_dir,f'{expname}.xml')
logger.info(f'Rocoto XML file: {rocoto_xml_file}')
with open(rocoto_xml_file,'wt') as fd:
    fd.write(rocoto_xml)
logger.info('Workflow XML file is generated.')
logger.info('Use Rocoto to execute this workflow.')

