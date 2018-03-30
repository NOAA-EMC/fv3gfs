"""!Internal representation types for tasks and workflows

@note Basic python concepts in use

To develop or understand this file, you must be fluent in the
following basic Python concepts:

- namedtuple
- inheritance
"""

from functools import reduce
import operator, io, logging, itertools
from datetime import timedelta
from abc import abstractmethod
from collections import namedtuple, OrderedDict, Sequence
from collections.abc import Mapping, Sequence
from copy import copy, deepcopy
from crow.config.exceptions import *
from crow.config.eval_tools import dict_eval, strcalc, multidict, from_config, update_globals
from crow.tools import to_timedelta, typecheck, NamedConstant, MISSING

__all__=[ 'SuiteView', 'Suite', 'Depend', 'LogicalDependency',
          'AndDependency', 'OrDependency', 'NotDependency',
          'StateDependency', 'Dependable', 'Taskable', 'Task',
          'Family', 'Cycle', 'RUNNING', 'COMPLETED', 'FAILED',
          'TRUE_DEPENDENCY', 'FALSE_DEPENDENCY', 'SuitePath',
          'CycleExistsDependency', 'FamilyView', 'TaskView',
          'CycleView', 'Slot', 'InputSlot', 'OutputSlot', 'Message',
          'Event', 'DataEvent', 'ShellEvent', 'EventDependency',
          'TaskExistsDependency', 'TaskArray', 'TaskElement',
          'DataEventElement', 'ShellEventElement' ]

class Event(dict_eval): pass
class DataEvent(Event): pass
class ShellEvent(Event): pass

RUNNING=NamedConstant('RUNNING')
COMPLETED=NamedConstant('COMPLETED')
FAILED=NamedConstant('FAILED')
_logger=logging.getLogger('crow.config')
VALID_STATES=[ 'RUNNING', 'FAILED', 'COMPLETED' ]
ZERO_DT=timedelta()
EMPTY_DICT={}
SUITE_SPECIAL_KEYS=set([ 'parent', 'up', 'task_path', 'task_path_var',
                         'task_path_str', 'task_path_list', 'this' ])
SLOT_SPECIALS = SUITE_SPECIAL_KEYS|set([ 'slot', 'flow', 'actor', 'meta',
                                         'Out', 'Loc'])

def subdict_iter(d):
    typecheck('d',d,Mapping)
    dkeys=[k for k in d.keys()]
    vallist=[v for v in d.values()]
    piter=itertools.product(*vallist)
    dvalues=[p for p in piter]
    for j in range(len(dvalues)):
        yield dict([i for i in zip(dkeys,dvalues[j])])

class SuitePath(list):
    """!Simply a list that can be hashed."""
    def __hash__(self):
        result=0
        for element in self:
            result=result^hash(element)
        return result

class SuiteView(Mapping):
    LOCALS=set(['suite','viewed','path','parent','__cache','__globals',
                '_more_globals'])
    def __init__(self,suite,viewed,path,parent,
                 task_array_dimensions=None,
                 task_array_dimval=None,
                 task_array_dimidx=None):
        # assert(isinstance(suite,Suite))
        # assert(isinstance(viewed,dict_eval))
        assert(hasattr(self,'_iter_raw'))
        assert(isinstance(parent,SuiteView))
        assert(not isinstance(viewed,SuiteView))
        if task_array_dimensions:
            self.task_array_dimensions=OrderedDict(
                task_array_dimensions)
        else:
            self.task_array_dimensions=OrderedDict()
        if task_array_dimidx:
            self.task_array_dimidx=OrderedDict(
                task_array_dimidx)
        else:
            self.task_array_dimidx=OrderedDict()
        if task_array_dimval:
            self.task_array_dimval=OrderedDict(
                task_array_dimval)
        else:
            self.task_array_dimval=OrderedDict()
        self.suite=suite
        self.viewed=viewed
        self.viewed.task_path_list=path[1:]
        self.viewed.task_path_str='/'+'/'.join(path[1:])
        self.viewed.task_path_var='.'.join(path[1:])
        if self.viewed.task_path_var:
            self.viewed._path=self.viewed.task_path_var
        if type(self.viewed) in SUITE_CLASS_MAP:
            self.viewed.up=parent
            self.viewed.this=self.viewed
        elif not isinstance(self.viewed,Cycle):
            assert(False)
        self.path=SuitePath(path)
        self.parent=parent
        self.__cache={}
        assert(isinstance(self.viewed,Cycle) or 'this' in self.viewed)
        if isinstance(self.viewed,Slot):
            locals=multidict(self.parent,self.viewed)
            globals=self.viewed._get_globals()
            for k,v in self.viewed._raw_child().items():
                if hasattr(v,'_as_dependency'): continue
                self.viewed[k]=from_config(k,v,globals,locals,self.viewed._path)
        if isinstance(self.viewed,Task):
            assert(isinstance(self.viewed,Cycle) or 'this' in self.viewed)
            for k,v in self.viewed.items():
                copied=False
                if hasattr(v,"_validate"):
                    copied=True
                    v=copy(v)
                    v._validate('suite')
                if self.__can_wrap(v):
                    if not copied:
                        v=copy(v)
                    self.viewed[k]=v
        assert(isinstance(viewed,Cycle) or self.viewed.task_path_var != parent.task_path_var)

    def _is_suite_view(self): pass

    def _raw(self,key):
        return self.viewed._raw(key)

    def _iter_raw(self):
        if hasattr(self.viewed,'_iter_raw'):
            for r in self.viewed._iter_raw():
                yield r

    def _invalidate_cache(self,key):
        self.__cache={}
        if hasattr(self.viewed,'_invalidate_cache'):
            self.viewed._invalidate_cache(key)

    def _globals(self):
        return self.viewed._globals()

    def __eq__(self,other):
        return self.path==other.path and self.suite is other.suite

    def __hash__(self):
        return hash(self.path)

    def has_cycle(self,dt):
        return CycleExistsDependency(to_timedelta(dt))

    def __len__(self):
        return len(self.viewed)

    def __iter__(self):
        for var in self.viewed: yield var

    def __repr__(self):
        return f'{type(self.viewed).__name__}@{self.path}'

    def __str__(self):
        s=str(self.viewed)
        if self.path[0]:
            s=f'dt=[{self.path[0]}]:'+s
        return s

    def depend(self,string,**kwargs):
        for k,v in kwargs.items():
            if not isinstance(v,Sequence):
                kwargs[k]=[v]
        deps=TRUE_DEPENDENCY
        for d in subdict_iter(kwargs):
            name=eval(f"f'''{string}'''",self.viewed._globals(),d)
            deps = deps & self[name]
        return deps

    def get_trigger_dep(self):
        t=self.get('Trigger',None)
        return TRUE_DEPENDENCY if t is None else t

    def get_complete_dep(self):
        t=self.get('Complete',None)
        return FALSE_DEPENDENCY if t is None else t

    def get_time_dep(self):
        t=self.get('Time',None)
        return timedelta.min if t is None else t

    def child_iter(self):
        """!Iterates over all tasks and families that are direct 
        children of this family, yielding a SuiteView of each."""
        for var,rawval in self.viewed._raw_child().items():
            if var=='up': continue
            if var=='this': continue
            if hasattr(rawval,'_as_dependency'): continue
            if self.__can_wrap(rawval):
                yield self[var]
            #if hasattr(val,'_is_suite_view'):
            #    yield val

    def walk_task_tree(self):
        """!Iterates over the entire tree of descendants below this
        SuiteView in a depth-first manner, yielding a SuiteView of
        each."""
        for val in self.child_iter():
            yield val
            if hasattr(val,'_is_suite_view'):
                for t in val.walk_task_tree():
                    yield t

    def __contains__(self,key):
        return key in self.viewed

    def is_task(self): return isinstance(self.viewed,Task)
    def is_family(self): return isinstance(self.viewed,Family)
    def is_cycle(self): return isinstance(self.viewed,Cycle)
    def is_input_slot(self): return isinstance(self.viewed,InputSlot)
    def is_output_slot(self): return isinstance(self.viewed,OutputSlot)
    def is_shell_event(self): return isinstance(self.viewed,ShellEvent)
    def is_data_event(self): return isinstance(self.viewed,DataEvent)
    def is_event(self): return isinstance(self.viewed,Event)

    def at(self,dt):
        dt=to_timedelta(dt)
        cls=type(self)
        ret=cls(self.suite,self.viewed,
                         [self.path[0]+dt]+self.path[1:],self.parent)
        return ret

    def __getattr__(self,key):
        if key in SuiteView.LOCALS: raise AttributeError(key)
        if key in self: return self[key]
        raise AttributeError(f'{self.viewed._path}: no {key} in {list(self.keys())}')

    def __getitem__(self,key):
        assert(isinstance(key,str))
        if key in self.__cache: return self.__cache[key]
        if key not in self.viewed:
            raise KeyError(f'{key}: not in {", ".join([k for k in self.keys()])}')
        val=self.viewed[key]
        
        if hasattr(val,'_is_suite_view'):
            return val
        elif type(val) in SUITE_CLASS_MAP:
            val=self.__wrap(key,val)
        elif isinstance(val,TaskArray):
            val=self.__wrap(key,val)
        elif hasattr(val,'_as_dependency'):
            locals=multidict(self.parent,self)
            val=self.__wrap(key,val._as_dependency(
                self.viewed._globals(),locals,self.path))
        self.__cache[key]=val
        return val

    def __can_wrap(self,obj):
        return( isinstance(obj,Cycle) or \
                hasattr(obj,'_generate') or \
                type(obj) in SUITE_CLASS_MAP )

    def __wrap(self,key,obj):
        if isinstance(obj,Cycle):
            # Reset path when we see a cycle
            obj=copy(obj)
            self.viewed[key]=obj
            return CycleView(self.suite,obj,self.path[:1],self)
        elif hasattr(obj,'_generate'):
            return self.__wrap(key,obj._generate(self))
        elif type(obj) in SUITE_CLASS_MAP:
            view_class=SUITE_CLASS_MAP[type(obj)]
            obj=copy(obj)
            if 'Rocoto' in obj and key=='final':
                assert(type(obj._raw("Rocoto"))!=str)
                #print(f'{key}.Rocoto: {type(obj._raw("Rocoto"))}')
            self.viewed[key]=obj
            return view_class(self.suite,obj,self.path+[key],self)
        return obj

    # Dependency handling.  When this SuiteView is wrapped around a
    # Task or Family, these operators will generate dependencies.

    def __and__(self,other):
        dep=as_dependency(other)
        if dep is NotImplemented: return dep
        return AndDependency(as_dependency(self),dep)
    def __or__(self,other):
        dep=as_dependency(other)
        if dep is NotImplemented: return dep
        return OrDependency(as_dependency(self),dep)
    def __invert__(self):
        return NotDependency(StateDependency(self,COMPLETED))
    def is_running(self):
        return StateDependency(self,RUNNING)
    def is_failed(self):
        return StateDependency(self,FAILED)
    def is_completed(self):
        return StateDependency(self,COMPLETED)
    def exists(self):
        return TaskExistsDependency(self)

    def get_alarm(self,default=MISSING):
        if 'AlarmName' not in self:
            if default==MISSING:
                return self.suite.Clock
            return default
        try:
            alarm=self.suite.get_alarm_with_name(self.AlarmName)
            return alarm
        except KeyError as ke:
            raise ValueError(f'{self.task_path_var}: no alarm with name {self.AlarmName} in suite.')

class EventView(SuiteView): pass

class SlotView(SuiteView):
    def __init__(self,suite,viewed,path,parent,search=MISSING):
        super().__init__(suite,copy(viewed),path,parent)
        assert(isinstance(path,Sequence))
        if search is MISSING: 
            self.__search={}
            return
        for naughty in search:
            if naughty in SLOT_SPECIALS:
                pathstr='.'.join(path[1:])
                raise ValueError(
                    f'{pathstr}: {naughty}: cannot be in meta')
        self.__search=dict()
    def get_actor_path(self):
        return '.'.join(self.path[1:-1])
    def get_slot_name(self):
        return self.path[-1]
    def get_search(self):
        return self.__search
    @abstractmethod
    def get_flow_name(self): pass
    def slot_iter(self):
        cls=type(self)
        arrays=list()
        names=list()
        for k in self:
            if k in SLOT_SPECIALS: continue
            v=self[k]
            if not isinstance(v,Sequence): continue
            if isinstance(v,str): continue
            names.append(k)
            arrays.append(v)
        if not names:
            yield self
            return
        lens=[ len(a) for a in arrays ]
        index=[ 0 ] * len(lens)
        while True:
            result=cls(self.suite,copy(self.viewed),self.path,
                       self.parent,self.__search)
            for i in range(len(arrays)):
                result.viewed[names[i]]=self[names[i]][index[i]]
            yield result
            for i in range(len(arrays)):
                index[i]+=1
                if index[i]<lens[i]: break
                if i == len(arrays)-1: return
                index[i]=0
    def get_meta(self):
        d=dict()
        for k in self:
            if k in SLOT_SPECIALS: continue
            v=self[k]
            if type(v) in [ int, float, bool, str ]:
                d[k]=v
        return d
    def __call__(self,**kwargs):
        cls=type(self)
        return cls(self.suite,self.viewed,self.path,
                   self.parent,kwargs)
    def __invert__(self): raise TypeError('cannot invert a Slot')
    def is_running(self): raise TypeError('data cannot run')
    def is_failed(self): raise TypeError('data cannot run')
    def is_completed(self): raise TypeError('data cannot run')

class CycleView(SuiteView): pass
class TaskableView(SuiteView): pass
class TaskView(TaskableView): pass
class FamilyView(TaskableView): pass
class InputSlotView(SlotView):
    def get_output_slot(self,meta):
        result=self.viewed._raw('Out')
        if not isinstance(result,Message):
            raise TypeError(f'{self.viewed._path}.Out: Must be a Message, not a {type(result).__name__}')
        return result._as_dependency(self._globals(),multidict(self.parent,meta),
                                     f'{self.viewed._path}.Out')
    def get_flow_name(self): return 'I'
class OutputSlotView(SlotView):
    def get_flow_name(self): return 'O'
    def get_slot_location(self): return self.Loc

class Suite(SuiteView):
    def __init__(self,suite,more_globals=EMPTY_DICT):
        if not isinstance(suite,Cycle):
            raise TypeError('The top level of a suite must be a Cycle not '
                            'a %s.'%(type(suite).__name__,))
        viewed=deepcopy(suite)
        old_doc=suite._get_globals()['doc']
        globals=dict(viewed._globals())
        assert(globals['tools'] is not None)
        globals.update(suite=self,
                       RUNNING=RUNNING,COMPLETED=COMPLETED,
                       FAILED=FAILED)
        self._more_globals=dict(more_globals)
        globals.update(self._more_globals)

        super().__init__(self,viewed,[ZERO_DT],self)

        update_globals(self.viewed._globals()['doc'],globals)
    def has_cycle(self,dt):
        return CycleExistsDependency(to_timedelta(dt))
    def make_empty_copy(self,more_globals=EMPTY_DICT):
        suite_copy=deepcopy(self)
        new_more_globals=copy(suite_copy._more_globals)
        new_more_globals.update(more_globals)
        return Suite(suite_copy,new_more_globals)
    def update_globals(self,*args,**kwargs):
        globals=dict()
        globals.update(*args,**kwargs)
        update_globals(self.viewed,globals)
    def get_alarm_with_name(self,alarm_name):
        return self["Alarms"][alarm_name]

class Message(str):
    def _as_dependency(self,globals,locals,path):
        try:
            return eval(self,globals,locals)
        except(ValueError,SyntaxError,TypeError,KeyError,NameError,IndexError,AttributeError) as ke:
            raise DependError(f'!Message {self}: {ke}')

class Depend(str):
    def _as_dependency(self,globals,locals,path):
        try:
            result=eval(self,globals,locals)
            result=as_dependency(result,path)
            return result
        except(AttributeError,KeyError,NameError) as ne:
            raise DependError(f'{".".join(path[1:])}@{path[0]}: !Depend {self}: {ne} --in-- {{{", ".join([k for k in locals.keys()])}}}')
        except(ValueError,SyntaxError,TypeError,IndexError) as ke:
            raise DependError(f'{path}: !Depend {self}: {ke}')

def as_dependency(obj,path=MISSING,state=COMPLETED):
    """!Converts the containing object to a State.  Action objects are
    compared to the "complete" state."""
    if isinstance(obj,EventView):
        return EventDependency(obj)
    elif isinstance(obj,SlotView):
        raise TypeError(f'Dependencies are not connected to the dataflow '
                        'subsystem yet.  Use Event dependencies instead.')
    elif isinstance(obj,SuiteView):
        return StateDependency(obj,state)
    elif isinstance(obj,LogicalDependency):
        return obj
    elif obj is None:
        return None
    raise TypeError(
        f'{type(obj).__name__} is not a valid type for a dependency')

class LogicalDependency(object):
    def __invert__(self):          return NotDependency(self)
    def __contains__(self,dep):    return False
    def __and__(self,other):
        if other is FALSE_DEPENDENCY: return other
        if other is TRUE_DEPENDENCY: return self
        dep=as_dependency(other)
        if dep is NotImplemented: raise TypeError(other)
        return AndDependency(self,dep)
    def __or__(self,other):
        if other is TRUE_DEPENDENCY: return other
        if other is FALSE_DEPENDENCY: return self
        dep=as_dependency(other)
        if dep is NotImplemented: raise TypeError(other)
        return OrDependency(self,dep)
    def __iter__(self):
        return
        yield self # ensure this is an iterator.
    @abstractmethod
    def copy_dependencies(self): pass
    @abstractmethod
    def add_time(self,dt): pass

class AndDependency(LogicalDependency):
    def __init__(self,*args):
        if not args: raise ValueError('Tried to create an empty AndDependency')
        self.depends=list(args)
        for dep in self.depends:
            typecheck(f'Dependencies',dep,LogicalDependency)
    def __len__(self):     return len(self.depends)
    def __str__(self):     return '( '+' & '.join([str(r) for r in self])+' )'
    def __repr__(self):    return f'AndDependency({repr(self.depends)})'
    def __hash__(self):    return reduce(operator.xor,[hash(d) for d in self])
    def __contains__(self,dep):
        return dep in self.depends
    def __and__(self,other):
        if other is TRUE_DEPENDENCY: return self
        if other is FALSE_DEPENDENCY: return other
        if isinstance(other,AndDependency):
            return AndDependency(*(self.depends+other.depends))
        dep=as_dependency(other)
        if dep is NotImplemented: return dep
        return AndDependency(*(self.depends+[dep]))
    def __iter__(self):
        for dep in self.depends:
            yield dep
    def __eq__(self,other):
        return isinstance(other,AndDependency) and self.depends==other.depends
    def copy_dependencies(self):
        return AndDependency(*[ dep.copy_dependencies() for dep in self ])
    def add_time(self,dt):
        for dep in self:
            dep.add_time(dt)

class OrDependency(LogicalDependency):
    def __init__(self,*args):
        if not args: raise ValueError('Tried to create an empty OrDependency')
        self.depends=list(args)
        for dep in self.depends:
            typecheck('A dependency',dep,LogicalDependency)
    def __str__(self):     return '( '+' | '.join([str(r) for r in self])+' )'
    def __repr__(self):    return f'OrDependency({repr(self.depends)})'
    def __len__(self):     return len(self.depends)
    def __hash__(self):    return reduce(operator.xor,[hash(d) for d in self])
    def __contains__(self,dep):
        return dep in self.depends
    def __or__(self,other):
        if other is FALSE_DEPENDENCY: return self
        if other is TRUE_DEPENDENCY: return other
        if isinstance(other,OrDependency):
            return OrDependency(*(self.depends+other.depends))
        dep=as_dependency(other)
        if dep is NotImplemented: return dep
        return OrDependency(*(self.depends+[dep]))
    def __iter__(self):
        for dep in self.depends:
            yield dep
    def __eq__(self,other):
        return isinstance(other,OrDependency) and self.depends==other.depends
    def copy_dependencies(self):
        return OrDependency(*[ dep.copy_dependencies() for dep in self ])
    def add_time(self,dt):
        for dep in self:
            dep.add_time(dt)

class NotDependency(LogicalDependency):
    def __init__(self,depend):
        typecheck('A dependency',depend,LogicalDependency)
        self.depend=depend
    def __invert__(self):        return self.depend
    def __str__(self):           return f'~ {self.depend}'
    def __repr__(self):          return f'NotDependency({repr(self.depend)})'
    def __iter__(self):          yield self.depend
    def __hash__(self):          return hash(self.depend)
    def __contains__(self,dep):  return self.depend==dep
    def add_time(self,dt):       self.depend.add_time(dt)
    def __eq__(self,other):
        return isinstance(other,NotDependency) and self.depend==other.depend
    def copy_dependencies(self):
        return NotDependency(self.depend.copy_dependencies())

class CycleExistsDependency(LogicalDependency):
    def __init__(self,dt):        self.dt=dt
    def __repr__(self):           return f'cycle_exists({self.dt})'
    def __hash__(self):           return hash(self.dt)
    def add_time(self,dt):        self.dt+=dt
    def copy_dependencies(self):  return CycleExistsDependency(self.dt)
    def __eq__(self,other):
        return isinstance(other,CycleExistsDependency) and self.dt==other.dt

class TaskExistsDependency(LogicalDependency):
    def __init__(self,view):
        typecheck('view',view,TaskableView,'Task or Tamily')
        self.view=view
    @property
    def path(self):              return self.view.path
    def is_task(self):           return self.view.is_task()
    def __hash__(self):          return hash(self.view.path)
    def copy_dependencies(self): return TaskExistsDependency(self.view)
    def add_time(self,dt):
        self.view=copy(self.view)
        self.view.path[0]+=dt
    def __repr__(self):
        return f'/{"/".join([str(s) for s in self.view.path])} exists'
    def __eq__(self,other):
        return isinstance(other,StateDependency) \
            and other.view.path==self.view.path

class StateDependency(LogicalDependency):
    def __init__(self,view,state):
        if state not in [ COMPLETED, RUNNING, FAILED ]:
            raise TypeError('Invalid state.  Must be one of the constants '
                            'COMPLETED, RUNNING, or FAILED')
        typecheck('view',view,SuiteView)
        if isinstance(view,SlotView):
            raise NotImplementedError('Data dependencies are not implemented')
        self.view=view
        self.state=state
    @property
    def path(self):              return self.view.path
    def is_task(self):           return self.view.is_task()
    def __hash__(self):          return hash(self.view.path)^hash(self.state)
    def copy_dependencies(self): return StateDependency(self.view,self.state)
    def add_time(self,dt):
        self.view=copy(self.view)
        self.view.path[0]+=dt
    def __repr__(self):
        return f'/{"/".join([str(s) for s in self.view.path])}'\
               f'={self.state}'
    def __eq__(self,other):
        return isinstance(other,StateDependency) \
            and other.state==self.state \
            and other.view.path==self.view.path

class EventDependency(LogicalDependency):
    def __init__(self,event):
        typecheck('event',event,EventView)
        self.event=event
    @property
    def path(self):              return self.event.path
    def is_task(self):           return self.event.is_task()
    def __hash__(self):          return hash(self.event.path)
    def copy_dependencies(self): return EventDependency(self.event)
    def add_time(self,dt):
        self.event=copy(self.event)
        self.event.path[0]+=dt
    def __repr__(self):
        return f'/{"/".join([str(s) for s in self.event.path[:-1]])}'\
            f':{self.event.path[-1]}'
    def __eq__(self,other):
        return isinstance(other,EventDependency) \
            and other.event.path==self.event.path

class TrueDependency(LogicalDependency):
    def __and__(self,other):     return other
    def __or__(self,other):      return self
    def __invert__(self):        return FALSE_DEPENDENCY
    def __eq__(self,other):      return isinstance(other,TrueDependency)
    def __hash__(self):          return 1
    def __copy__(self):          return TRUE_DEPENDENCY
    def __deepcopy__(self):      return TRUE_DEPENDENCY
    def copy_dependencies(self): return TRUE_DEPENDENCY
    def __repr__(self):          return 'TRUE_DEPENDENCY'
    def __str__(self):           return 'TRUE'
    def add_time(self,dt):       pass

class FalseDependency(LogicalDependency):
    def __and__(self,other):     return self
    def __or__(self,other):      return other
    def __invert__(self):        return TRUE_DEPENDENCY
    def __eq__(self,other):      return isinstance(other,FalseDependency)
    def __hash__(self):          return 0
    def __copy__(self):          return FALSE_DEPENDENCY
    def __deepcopy__(self):      return FALSE_DEPENDENCY
    def copy_dependencies(self): return FALSE_DEPENDENCY
    def __repr__(self):          return 'FALSE_DEPENDENCY'
    def __str__(self):           return 'FALSE'
    def add_time(self,dt):       pass

TRUE_DEPENDENCY=TrueDependency()
FALSE_DEPENDENCY=FalseDependency()

class Dependable(dict_eval):
    def __str__(self):
        sio=io.StringIO()
        sio.write(f'{type(self).__name__}@{self._path}')
        sio.write('{')
        first=True
        for k,v in self._raw_child().items():
            if k not in SUITE_SPECIAL_KEYS:
                sio.write(f'{", " if not first else ""}{k}={v!r}')
                first=False
        sio.write('}')
        v=sio.getvalue()
        sio.close()
        return v

class Slot(Dependable): pass
class InputSlot(Slot): pass
class OutputSlot(Slot): pass

class Taskable(Dependable): pass
class Task(Taskable): pass
class Family(Taskable): pass
class Cycle(dict_eval): pass

class TaskArrayElement(dict_eval):
    def _duplicate(self,parent,dimensions,dimval,dimidx):
        child_dimensions=dimensions
        if 'Foreach' in self:
            typecheck(f'{self._path}.Foreach',self.Foreach,Sequence,'sequence')
            d2=dict()
            for idxname in self.Foreach:
                if idxname in dimensions:
                    d2[idxname]=dimensions[idxname]
                else:
                    raise KeyError(f'{self._path}.Foreach: {idxname}: no such dimension')
            dimensions=d2
        dict_iter=[{}]
        if dimensions:
            dimensions_to_dimidx=dict()
            for k,v in dimensions.items():
                dimensions_to_dimidx[k]=[n for n in range(len(v))]
            dict_iter=subdict_iter(dimensions_to_dimidx)
        for more_dimidx in dict_iter:
            child_dimidx=copy(dimidx)
            child_dimidx.update(more_dimidx)
            child_dimval=dict()
            for i_dimname,i_dimidx in child_dimidx.items():
                child_dimval[i_dimname]=dimensions[i_dimname][i_dimidx]
            cls=ARRAY_ELEMENT_TYPE_MAP[type(self)]
            t=cls(self._raw_child(),globals=self._globals())
            t._path=self._path # used if Name is missing
            t['dimlist']=dict_eval(dimensions)
            t['dimval']=dict_eval(child_dimval)
            t['dimidx']=dict_eval(child_dimidx)
            name=t.Name
            t._path=f'{parent._path}.{name}'
            for k,v in self._raw_child().items():
                if hasattr(v,'_duplicate'):
                    for name2,content2 in v._duplicate(
                            t,child_dimensions,dimval,dimidx):
                        t[name2]=content2
            yield name,t

class DataEventElement(TaskArrayElement): pass
class ShellEventElement(TaskArrayElement): pass
class TaskElement(TaskArrayElement): pass

    # def _duplicate(self,dimensions,dimval):
    #     if 'Foreach' in self:
    #         typecheck(f'{self._path}.Foreach',self.Foreach,Sequence,'sequence')
    #         d2=dict()
    #         for idxname in self.Foreach:
    #             if idxname in dimensions:
    #                 d2[idxname]=dimensions[idxname]
    #             else:
    #                 raise KeyError(f'{self._path}.Foreach: {idxname}: no such dimension')
    #         dimensions=d2
    #     dict_iter=[{}]
    #     if dimensions:
    #         dict_iter=subdict_iter(dimensions)
    #     for more_dimval in dict_iter:
    #         child_dimval=copy(dimval)
    #         child_dimval.update(more_dimval)
    #         t=Task(self._raw_child(),globals=self._globals())
    #         t._path=self._path # used if Name is missing
    #         t['idx']=dict_eval(child_dimval)
    #         name=t.Name
    #         t._path=f'{self._path}.{name}'
    #         yield name,t

class TaskArray(dict_eval):
    def _generate(self,parent_view):
        f=Family(self._raw_child(),path=self._path,globals=self._globals())
        dimensions=copy(parent_view.task_array_dimensions)
        dimidx=copy(parent_view.task_array_dimidx)
        dimval=copy(parent_view.task_array_dimval)
        child_dimensions=self.Dimensions
        dimensions.update(child_dimensions)
        for dimname,dimlist in child_dimensions.items():
            if not isinstance(dimlist,Sequence):
                raise TypeError(f'{self._path}: dimension {dimname} is not a list (is type {type(dimlist).__name__}).')
        for k,v in self._raw_child().items():
            if hasattr(v,'_duplicate'):
                for name,content in v._duplicate(f,child_dimensions,dimval,dimidx):
                    f[name]=content
            else:
                f[k]=v
        if 'Trigger' in self:
            assert('Trigger' in f)
        return f


ARRAY_ELEMENT_TYPE_MAP={
    TaskElement: Task,
    DataEventElement: DataEvent,
    ShellEventElement: ShellEvent
}


# class TaskArray(TaskableGenerator):
#     def __init__(self,*args,**kwargs):
#         super().init(*args,**kwargs)
#         Dimval=self.Dimval
#         varname=Index[0]
#         if not isinstance(varname,str):
#             raise TypeError('Index first argument should be a string variable '
#                             'name not a %s'%(type(varname.__name__),))
#         values=Index[1]
#         if not isinstance(values,Sequence):
#             raise TypeError('Index second argument should be a sequence '
#                             'name not a %s'%(type(values.__name__),))
#         self.__instances=[MISSING]*len(values)
#     @property
#     def index_name(self):
#         return self['Index'][0]
#     @property
#     def index_count(self):
#         return len(self['Index'][1])
#     def index_keys(self):
#         keys=self['Index'][1]
#         for k in keys: yield k
#     def index_items(self):
#         varname=self.index_name
#         keys=self['Index'][1]
#         for i in len(keys):
#             yield keys[i],self.__for_index(i,varname,key)
#     def for_index(self,i):
#         if self.__instances[i] is not MISSING:
#             return self.__instances[i]
#         varname=self.index_name
#         keys=self['Index'][1]
#         return self.__for_index(i,varname,key)
#     def __for_index(self,i,varname,key):
#         the_copy=Family(self._raw_child())
#         the_copy[varname]=key

SUITE_CLASS_MAP={ Task:TaskView, Family: FamilyView, Event: EventView,
                  DataEvent: EventView, ShellEvent: EventView,
                  OutputSlot: OutputSlotView, InputSlot:InputSlotView}
