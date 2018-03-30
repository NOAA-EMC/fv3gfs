import yaml, logging, os, io, re, glob

from collections import Sequence, Mapping

import crow.tools

from .from_yaml import ConvertFromYAML
from .template import Template
from .represent import Action, Platform, ShellCommand
from .tools import CONFIG_TOOLS, ENV
from .tasks import Suite, Depend, AndDependency, SuitePath, \
    OrDependency, NotDependency, StateDependency, Dependable, \
    Taskable, Task, Family, Cycle, LogicalDependency, SuiteView, \
    RUNNING, COMPLETED, FAILED, TRUE_DEPENDENCY, FALSE_DEPENDENCY, \
    CycleExistsDependency, InputSlot, OutputSlot, EventDependency, \
    Event, DataEvent, ShellEvent, TaskExistsDependency
from .to_yaml import to_yaml
from .eval_tools import invalidate_cache, update_globals
from .eval_tools import evaluate_immediates as _evaluate_immediates
from .exceptions import ConfigError, ConfigUserError

__all__=["from_string","from_file","to_py", 'Action', 'Platform', 'Template',
         'TaskStateAnd', 'TaskStateOr', 'TaskStateNot', 'TaskStateIs',
         'Taskable', 'Task', 'Family', 'CycleAt', 'CycleTime', 'Cycle',
         'Trigger', 'Depend', 'Timespec', 'SuitePath', 'ShellEvent', 'Event',
         'DataEvent', 'CycleExistsDependency', 'validate', 'EventDependency',
         'TaskExistsDependency', 'follow_main', 'from_dir', 'update_globals' ]

_logger=logging.getLogger('crow.config')

def to_py(obj):
    return obj._to_py() if hasattr(obj,'_to_py') else obj

def expand_text(text,scope):
    if hasattr(scope,'_expand_text'):
        return scope._expand_text(text)
    raise TypeError('In expand_text, the "scope" parameter must be an '
                    'object with the _expand_text argument.  You sent a '
                    '%s.'%(type(scope).__name__))

evaluate_immediates=_evaluate_immediates

def from_string(s,evaluate_immediates=True,validation_stage=None):
    if not s: raise TypeError('Cannot parse null string')
    c=ConvertFromYAML(yaml.load(s),CONFIG_TOOLS,ENV)
    result=c.convert(validation_stage=validation_stage,
                     evaluate_immediates=evaluate_immediates)
    return result

def from_file(*args,evaluate_immediates=True,validation_stage=None):
    if not args: raise TypeError('Specify which files to read.')
    data=list()
    for file in args:
        with open(file,'rt') as fopen:
            data.append(fopen.read())
    return from_string(u'\n\n\n'.join(data),
                       evaluate_immediates=evaluate_immediates,
                       validation_stage=validation_stage)

def _recursive_validate(obj,stage,memo=None):
    if memo is None: memo=set()
    if id(obj) in memo: return
    memo.add(id(obj))
    if hasattr(obj,'_do_not_validate'): return
    if hasattr(obj,'_validate'):
        obj._validate(stage)
        for k,v in obj.items():
            _recursive_validate(v,stage,memo)

def validate(obj,stage='',recurse=False):
    if recurse:
        _recursive_validate(obj,stage)
    elif hasattr(obj,'_validate'):
        obj._validate(stage)

def document_root(obj):
    return obj._globals()['doc']

def from_dir(reldir,evaluate_immediates=True,validation_stage=None,main_globals=None):
    with io.StringIO() as fd:
        follow_main(fd,reldir,main_globals)
        yaml=fd.getvalue()
    return from_string(yaml,evaluate_immediates=evaluate_immediates,
                       validation_stage=validation_stage)

def follow_main(fd,reldir,main_globals=None):
    if main_globals is None: main_globals={}
    _logger.debug(f"{reldir}: enter directory")
    mainfile=os.path.join(reldir,"_main.yaml")

    includes=[ "*.yaml" ]
    if os.path.exists(mainfile):
        _logger.debug(f"{mainfile}: read \"include\" array")
        maindat=crow.config.from_file(mainfile)
        maindat.update(main_globals)
        if "include" not in maindat or \
           not isinstance(maindat.include,Sequence):
            epicfail(f"{mainfile} has no \"include\" array")
        includes=maindat.include

    _logger.debug(f"{reldir}: scan {includes}")

    literals=set()
    # First pass: scan for literal files:
    for item in includes:
        if not re.search(r'[*?\[\]{}]',item):
            literals.add(item)

    # Second pass: read files:
    included=set()
    for item in includes:
        if item in included: continue
        is_literal=item in literals
        if is_literal:
            paths=[ os.path.join(reldir,item) ]
        else:
            paths=[ x for x in glob.glob(os.path.join(reldir,item)) ]
        _logger.debug(f"{reldir}: {item}: paths = {paths}")
        for path in paths:
            basename=os.path.basename(path)
            if basename in included: continue
            if not is_literal and basename in literals: continue
            if basename == "_main.yaml": continue
            if os.path.isdir(path):
                follow_main(fd,path,main_globals)
            else:
                _logger.debug(f"{path}: read yaml")
                included.add(basename)
                with open(path,"rt") as pfd:
                    fd.write(f"#--- {path}\n")
                    fd.write(pfd.read())
                    fd.write(f"\n#--- end {path}\n")
