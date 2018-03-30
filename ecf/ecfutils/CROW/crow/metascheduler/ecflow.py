import collections, datetime, re, logging
from collections import OrderedDict

from io import StringIO

import crow.tools
from copy import copy
from crow.tools import to_timedelta, typecheck, ZERO_DT
from crow.metascheduler.algebra import simplify, assume
from crow.metascheduler.graph import Graph
from crow.config import SuiteView, Suite, Depend, LogicalDependency, \
          AndDependency, OrDependency, NotDependency, \
          StateDependency, Dependable, Taskable, Task, \
          Family, Cycle, RUNNING, COMPLETED, FAILED, \
          TRUE_DEPENDENCY, FALSE_DEPENDENCY, SuitePath, validate, \
          CycleExistsDependency, invalidate_cache, EventDependency
__all__=['to_ecflow','ToEcflow']

f'This module requires python 3.6 or newer.'

_logger=logging.getLogger('to_ecflow')

ECFLOW_STATE_MAP={ COMPLETED:'complete',
                   RUNNING:'active',
                   FAILED:'aborted' }

def skip_fun(node):
    return not node.might_complete() or node.is_always_complete()

def relative_path(start,dest):
    """Used to generate relative paths for ecflow.  Removes common
    path components and adds ".." components to go up one or more
    families, to re-express dest in a path relative to start."""
    if not start:
        raise ValueError('relative_path start path must be non-empty')
    if not dest:
        raise ValueError('relative_path destination path must be non-empty')
    i=0 # Index of first element that differs between start and dest lists
    while i<len(start) and i<len(dest) and start[i]==dest[i]:
        i+=1
    if i==len(start)-1 and len(start)==len(dest):
        # Destination task is in the same family as start:
        return f'./{dest[-1]}'
    if i==0:
        # No commonality.  Use absolute path.
        return '/' + '/'.join(dest)
    if len(start)-i-1>0:
        return '../'*(len(start)-i-1) + '/'.join(dest[i:])
    else:
        return './'+'/'.join(dest[i:])
    
def undate_path(relative_time,format,suite_path,undated):
    """!In dependencies within crow.config, the task paths have a
    timedelta at element 0 to indicate the relative time of the
    dependency.  This creates a new path, replacing the timedelta with
    a time string.  The format is sent to datetime.strftime."""
    assert(isinstance(undated,OrderedDict))
    if suite_path and hasattr(suite_path[0],'total_seconds'):
        when=relative_time+suite_path[0]
        result=[when.strftime(format)] + suite_path[1:]
        return result,True
    return suite_path,False

def convert_state_dep(fd,task,dep,clock,time_format,negate,undated):
    assert(isinstance(undated,OrderedDict))
    typecheck('clock',clock,crow.tools.Clock)
    task_path,did_undated=undate_path(clock.now,time_format,task.path,undated)
    dep_path,did_undated=undate_path(clock.now,time_format,dep.view.path,undated)
    rel_path=relative_path(task_path,dep_path)
    if did_undated and rel_path[0]=='/':
        undated[rel_path]=1
    state=ECFLOW_STATE_MAP[dep.state]
    fd.write(f'{rel_path} {"!=" if negate else "=="} {state}')

def convert_event_dep(fd,task,dep_path,event_name,clock,time_format,negate,undated):
    assert(isinstance(undated,OrderedDict))
    typecheck('clock',clock,crow.tools.Clock)
    task_path,did_undated=undate_path(clock.now,time_format,task.path,undated)
    dep_path,did_undated=undate_path(clock.now,time_format,dep_path,undated)
    rel_path=relative_path(task_path,dep_path)
    if did_undated and rel_path[0]=='/':
        undated[rel_path]=1
    fd.write(f'{rel_path}:{event_name}{" is clear" if negate else ""}')

def dep_to_ecflow(fd,task,dep,clock,time_format,undated):
    assert(isinstance(undated,OrderedDict))
    first=True
    if isinstance(dep,OrDependency):
        for subdep in dep:
            if not first:
                fd.write(' or ')
            first=False
            dep_to_ecflow(fd,task,subdep,clock,time_format,undated)
    elif isinstance(dep,AndDependency):
        for subdep in dep:
            if not first:
                fd.write(' and ')
            first=False
            dep_to_ecflow(fd,task,subdep,clock,time_format,undated)
    elif isinstance(dep,NotDependency):
        fd.write('not ')
        if isinstance(dep.depend,StateDependency):
            convert_state_dep(fd,task,dep.depend,clock,time_format,True,
                              undated)
        elif isinstance(dep.depend,EventDependency):
            convert_event_dep(fd,task,dep.event.path[:-1],
                              dep.event.path[-1],clock,time_format,True,
                              undated)
        else:
            dep_to_ecflow(fd,task,dep.depend,clock,time_format,undated)
    elif isinstance(dep,StateDependency):
        convert_state_dep(fd,task,dep,clock,time_format,False,undated)
    elif isinstance(dep,EventDependency):
        convert_event_dep(fd,task,dep.event.path[:-1],
                          dep.event.path[-1],clock,time_format,False,undated)

class ToEcflow(object):
    def __init__(self,suite):
        if not isinstance(suite,Suite):
            raise TypeError('The suite argument must be a Suite, '
                            'not a '+type(suite).__name__)

        try:
            scheduler=suite.ecFlow.scheduler
            clock=copy(suite.Clock)
        except(AttributeError,IndexError,TypeError,ValueError) as e:
            raise ValueError(
                'A Suite must define an ecFlow section containing '
                'scheduler, and suite_name; and the suite must have a Clock')

        update_globals={ 'sched':scheduler, 'to_ecflow':self, 'clock':clock,
                         'metasched':self }

        if 'parallelism' in suite.ecFlow:
            update_globals['parallelism']=suite.ecFlow.parallelism

        cycles_to_write=suite.ecFlow.get('write_cycles',suite.Clock)
        cycles_to_analyze=suite.ecFlow.get('analyze_cycles',suite.Clock)

        if cycles_to_write not in cycles_to_analyze:
            raise ValueError(f'ecFlow.write_cycles: Cycles to write must be a subset of cycles to analyze')
        if cycles_to_analyze not in suite.Clock:
            raise ValueError(f'ecFlow.analyze_cycles: Cycles to analyze must be a subset of the suite clock.')

        self.suite=suite
        self.suite.update_globals(**update_globals)
        self.settings=self.suite.ecFlow
        self.indent=self.settings.get('indent','  ')
        self.sched=scheduler
        self.clock=copy(self.suite.Clock)
        self.undated=OrderedDict()
        self.graph=Graph(self.suite,self.suite.Clock)
        self.type='ecflow'

    def datestring(self,format):
        def replacer(m):
            return( (m.group(1) or "")+"%"+m.group(2)+"%" )
        return re.sub(r'(\%\%)*\%([a-zA-Z])',replacer,format)

    def defenvar(self,name,value):
        return f"edit {name} '{value!s}'"

    def defvar(self,name,value):
        return f"edit {name} '{value!s}'"

    def varref(self,name):
        return f'%{name}%'

    def _cycles_to_write(self):
        return self.suite.ecFlow.get('write_cycles',self.suite.Clock)

    def _cycles_to_analyze(self):
        return self.suite.ecFlow.get('analyze_cycles',self.suite.Clock)

    def _select_cycle(self,cycle):
        invalidate_cache(self.suite,recurse=True)
        validate(self.suite,stage='suite',recurse=True)
        self.suite.Clock.now = cycle

    def _foreach_cycle(self,clock):
        """!Iterates over all cycles in the clock, ensuring self.suite is
        correctly set up to handle a cycle within during each
        iteration.        """
        clock=copy(clock)
        # Cannot iterate over self.suite.Clock because
        # self.suite.Clock is not a Clock. It is an object that
        # generates a Clock.  Hence, invalidate_cache causes a new
        # clock to be generated.
        for clock in clock.iternow():
            self._select_cycle(clock.now)
            yield clock.now

    def _remove_final_task(self):
        if 'final' not in self.suite: return
        assert('final' in self.suite)
        for cycle in self._foreach_cycle(self._cycles_to_write()):
            dt=cycle-self.clock.start
            self.graph.force_never_run(self.suite.final.at(dt).path)

    def _initialize_graph(self):
        _logger.info('populate job graph...')
        self._populate_job_graph()
        _logger.info('simplify job graph...')
        self._remove_final_task()
        self._simplify_job_graph()

    def _populate_job_graph(self):
        for cycle in self._foreach_cycle(self._cycles_to_analyze()):
            _logger.info(f'{cycle:%Y%m%d%H%M}: populate job graph...')
            self.graph.add_cycle(cycle)

    def _simplify_job_graph(self):
        for cycle in self._foreach_cycle(self._cycles_to_write()):
            self.graph.simplify_cycle(cycle)

    def _walk_job_graph(self,cycle,skip_fun=None,enter_fun=None,exit_fun=None):
        self._select_cycle(cycle)
        for node in self.graph.depth_first_traversal(
                cycle,skip_fun,enter_fun,exit_fun):
            yield node

    def _make_suite_def(self,cycle):
        self._select_cycle(cycle)
        clock=self.suite.Clock

        suite_name_format=self.suite.ecFlow.suite_name
        suite_name=cycle.strftime(suite_name_format)
        undated=OrderedDict()
        sio=StringIO()

        if 'before_suite_def' in self.suite:
            sio.write(self.suite.before_suite_def)
            sio.write('\n')

        sio.write(f'suite {suite_name}\n')
        if 'ecflow_def' in self.suite:
            for line in self.suite.ecflow_def.splitlines():
                sio.write(f'{self.indent}{line.rstrip()}\n')

        def exit_fun(node):
            if node.is_family():
                indent=max(0,len(node.path)-1)*self.indent
                ended=f'/{suite_name}/{node.view.task_path_str}'
                ended=re.sub('/+','/',ended)
                sio.write(f'{indent}endfamily # {ended}\n')

        for node in self._walk_job_graph(cycle,skip_fun=skip_fun,exit_fun=exit_fun):
            indent0=max(0,len(node.path)-1)*self.indent
            indent1=max(0,len(node.path))*self.indent
            nodetype='task' if node.is_task() else 'family'
            sio.write(f'{indent0}{nodetype} {node.path[-1]}')
            if node.is_family():
                started=f' # /{suite_name}/{node.view.task_path_str}'
                started=re.sub('/+','/',started)
                sio.write(started)
            sio.write('\n')

            if 'ecflow_def' in node.view:
                for line in node.view.ecflow_def.splitlines():
                    sio.write(f'{indent1}{line.rstrip()}\n')

            if 'Dummy' in node.view and node.view.Dummy:
                sio.write(f"{indent1}edit ECF_DUMMY_TASK ''\n")
                sio.write(f"{indent1}defstatus complete\n")

            if node.trigger not in [FALSE_DEPENDENCY,TRUE_DEPENDENCY]:
                sio.write(f'{indent1}trigger ')
                dep_to_ecflow(sio,node,node.trigger,clock,suite_name_format,undated)
                sio.write('\n')
            if node.complete not in [FALSE_DEPENDENCY,TRUE_DEPENDENCY]:
                sio.write(f'{indent1}complete ')
                dep_to_ecflow(sio,node,node.complete,clock,suite_name_format,undated)
                sio.write('\n')
            if node.time>ZERO_DT:
                when=cycle+node.time
                ectime=when.strftime('%H:%M')
                sio.write(f'{indent1}time {ectime}\n')
                if self.settings.dates_in_time_dependencies:
                    ecdate=when.strftime('%d.%m.%Y')
                    sio.write(f'{indent1}date {ecdate}\n')

            event_number=node.view.get('ecflow_first_event_number',1)
            typecheck(f'{node.view.task_path_var}.ecflow_first_event_number',event_number,int)
            if node.is_task():
                for item in node.view.child_iter():
                    if item.is_event():
                        sio.write(f'{indent1}event {event_number} '
                                  f'{item.path[-1]}\n')
                    event_number+=1

        sio.write(f'endsuite # /{suite_name}\n')
        suite_def_without_externs=sio.getvalue()
        sio.close()
        sio=StringIO()
        if undated:
            for d in undated.keys():
                sio.write(f'extern {d}\n')
            sio.write(suite_def_without_externs)
            suite_def=sio.getvalue()
            sio.close()
        else:
            suite_def=suite_def_without_externs
        return suite_name, suite_def

    ####################################################################

    # ecf file generation

    def _make_task_ecf_files(self,ecf_files,ecf_file_set,
                               ecf_file_path,task):
        dt=self.suite.Clock.now-self.suite.Clock.start
        if skip_fun(self.graph.get_node(task.at(dt).path)):
            return
        ecf_file_set=task.get('ecf_file_set',ecf_file_set)
        ecf_file_path=ecf_file_path+[task.path[-1]]
        path_string='/'.join(ecf_file_path)
        if path_string in ecf_files[ecf_file_set]:
            return # This ecf file is already generated
        ecf_files[ecf_file_set][path_string]=task.ecf_file

    def _make_family_ecf_files(self,ecf_files,ecf_file_set,
                               ecf_file_path,family):
        dt=self.suite.Clock.now-self.suite.Clock.start
        if skip_fun(self.graph.get_node(family.at(dt).path)):
            return
        ecf_file_set=family.get('ecf_file_set',ecf_file_set)
        ecf_file_path=ecf_file_path+[family.path[-1]]
        for t in family.child_iter():
            if t.is_task():
                self._make_task_ecf_files(
                    ecf_files,ecf_file_set,ecf_file_path,t)
            elif t.is_family():
                self._make_family_ecf_files(
                    ecf_files,ecf_file_set,ecf_file_path,t)

    def _make_ecf_files_for_one_cycle(self,ecf_files):
        ecf_file_set=self.settings.get('ecf_file_set','ecf_files')
        for t in self.suite.child_iter():
            if t.is_task():
                self._make_task_ecf_files(ecf_files,ecf_file_set,list(),t)
            elif t.is_family():
                self._make_family_ecf_files(ecf_files,ecf_file_set,list(),t)
        return ecf_files

    ####################################################################

    def to_ecflow(self):
        suite_def_files=dict()
        ecf_files=collections.defaultdict(dict)
        self._initialize_graph()
        for cycle in self._foreach_cycle(self._cycles_to_write()):
            _logger.info(f'{cycle:%Y%m%d%H%M}: make suite definition in memory...')
            # Figure our where we are making the suite definition file:
            filename=cycle.strftime(self.suite.ecFlow.suite_def_filename)
            if filename in suite_def_files:
                # We already processed a cycle whose suite definition
                # is the same as this one's.  Skip.
                continue
            suite_name, suite_def = self._make_suite_def(cycle)
            assert(isinstance(suite_name,str))
            assert(isinstance(suite_def,str))
            suite_def_files[filename]={ 'name':suite_name, 'def':suite_def }
            _logger.info(f'{cycle:%Y%m%d%H%M}: make ecf files in memory...')
            self._make_ecf_files_for_one_cycle(ecf_files)
        del self.suite
        return suite_def_files,ecf_files

def to_ecflow(suite):
    typecheck('suite',suite,Suite)
    return ToEcflow(suite).to_ecflow()
