"""!Converts YAML objects to internal representations.

\note Advanced python concept in use.

You will not understand this file unless you are fluent in the
following python concept:

* Lexical functions

"""

from datetime import timedelta
from collections import namedtuple, OrderedDict

import collections, re, yaml, logging

from yaml import YAMLObject
from yaml.nodes import MappingNode
import crow.config.eval_tools
from crow.config.eval_tools import *
from crow.config.represent import *
from crow.config.tasks import *
from crow.config.template import *
from crow.config.exceptions import *
from crow.tools import to_timedelta
import crow.sysenv

__all__=['ConvertFromYAML']

logger=logging.getLogger('crow.config')

# YAML representation objects:
class PlatformYAML(YAMLObject):   yaml_tag=u'!Platform'
class SelectYAML(YAMLObject):     yaml_tag=u'!Select'
class ActionYAML(YAMLObject):     yaml_tag=u'!Action'
#class TemplateYAML(YAMLObject):   yaml_tag=u'!Template'

class FirstMaxYAML(list):         yaml_tag=u'!FirstMax'
class FirstMinYAML(list):         yaml_tag=u'!FirstMin'
class FirstTrueYAML(list):        yaml_tag=u'!FirstTrue'
class LastTrueYAML(list):         yaml_tag=u'!LastTrue'
class ImmediateYAML(list):        yaml_tag=u'!Immediate'
class InheritYAML(list):          yaml_tag=u'!Inherit'
class MergeMappingYAML(list):     yaml_tag=u'!MergeMapping'

class ClockYAML(dict):            yaml_tag=u'!Clock'
class EvalYAML(dict): pass
class ShellCommandYAML(dict): pass
class DataEventYAML(dict): pass
class ShellEventYAML(dict): pass
class TaskYAML(OrderedDict): pass
class TaskArrayYAML(OrderedDict): pass
class TaskElementYAML(OrderedDict): pass
class DataEventElementYAML(OrderedDict): pass
class ShellEventElementYAML(OrderedDict): pass
class FamilyYAML(OrderedDict): pass
class CycleYAML(OrderedDict): pass
class TemplateYAML(OrderedDict): pass
class InputSlotYAML(dict): pass
class OutputSlotYAML(dict): pass
class JobResourceSpecMakerYAML(list): pass

# Mapping from YAML representation class to a pair:
# * internal representation class
# * python core class for intermediate conversion
TYPE_MAP={ PlatformYAML:          [ Platform,     dict,        None ], 
           SelectYAML:            [ Select,       dict,        None ], 
           TemplateYAML:          [ Template,     OrderedDict, None ],
           ActionYAML:            [ Action,       dict,        None ],
           ShellCommandYAML:      [ ShellCommand, OrderedDict, None ],
           TaskYAML:              [ Task,         OrderedDict, None ],
           CycleYAML:             [ Cycle,        OrderedDict, None ],
           FamilyYAML:            [ Family,       OrderedDict, None ],
           DataEventYAML:         [ DataEvent,    dict,        None ],
           ShellEventYAML:        [ ShellEvent,   dict,        None ],
           TaskArrayYAML:         [ TaskArray,    OrderedDict, None ],
           TaskElementYAML:       [ TaskElement,  OrderedDict, None ],
           DataEventElementYAML:  [ DataEventElement,   OrderedDict, None ],
           ShellEventElementYAML: [ ShellEventElement,  OrderedDict, None ],
         }

def type_for(t,path):
    """!Returns an empty, internal representation, class for the given
    YAML type.  This is simply a wrapper around TYPE_MAP"""
    (internal_class,python_class,convert_class)=TYPE_MAP[type(t)]
    return ( internal_class(python_class(),path=path), convert_class )

########################################################################

def timedelta_constructor(loader,node):
    s=loader.construct_scalar(node)
    return to_timedelta(s)

ZERO_DT=timedelta()

def timedelta_representer(dumper,dt):
    pre=''
    if dt<ZERO_DT:
        dt=abs(dt)
        pre='-'
    hours=dt.seconds//3600
    minutes=(dt.seconds-hours*3600)//60
    seconds=dt.seconds-hours*3600-minutes*60
    rep=''
    if dt.days: rep=f'{dt.days}d'
    rep+=f'{hours:02d}:{minutes:02d}:{seconds:02d}'
    if dt.microseconds: rep+=f'.{dt.microseconds:06d}'
    return dumper.represent_scalar('!timedelta',rep)

yaml.add_representer(timedelta,timedelta_representer)
yaml.add_constructor('!timedelta',timedelta_constructor)

########################################################################

def add_yaml_string(key,cls):
    """!Generates and registers representers and constructors for custom
    string YAML types    """
    def representer(dumper,data):
        return dumper.represent_scalar(key,str(data))
    yaml.add_representer(cls,representer)
    def constructor(loader,node):
        return cls(loader.construct_scalar(node))
    yaml.add_constructor(key,constructor)

add_yaml_string(u'!expand',expand)
add_yaml_string(u'!calc',calc)
add_yaml_string(u'!error',user_error_message)
add_yaml_string(u'!Depend',Depend)
add_yaml_string(u'!Message',Message)

########################################################################

def add_yaml_mapping(key,cls): 
    """!Generates and registers representers and constructors for custom
    YAML sequence types    """
    def representer(dumper,data):
        return dumper.represent_mapping(key,data)
    def constructor(loader,node):
        return cls(loader.construct_mapping(node))
    yaml.add_representer(cls,representer)
    yaml.add_constructor(key,constructor)

add_yaml_mapping(u'!ShellCommand',ShellCommandYAML)
add_yaml_mapping(u'!DataEvent',DataEventYAML)
add_yaml_mapping(u'!ShellEvent',ShellEventYAML)

########################################################################

def add_yaml_sequence(key,cls): 
    """!Generates and registers representers and constructors for custom
    YAML sequence types    """
    def representer(dumper,data):
        return dumper.represent_sequence(key,data)
    def constructor(loader,node):
        return cls(loader.construct_sequence(node))
    yaml.add_representer(cls,representer)
    yaml.add_constructor(key,constructor)

add_yaml_sequence(u'!FirstMax',FirstMaxYAML)
add_yaml_sequence(u'!FirstMin',FirstMinYAML)
add_yaml_sequence(u'!LastTrue',LastTrueYAML)
add_yaml_sequence(u'!FirstTrue',FirstTrueYAML)
add_yaml_sequence(u'!Immediate',ImmediateYAML)
add_yaml_sequence(u'!Inherit',InheritYAML)
add_yaml_sequence(u'!MergeMapping',MergeMappingYAML)
add_yaml_sequence(u'!JobRequest',JobResourceSpecMakerYAML)

## @var CONDITIONALS
# Used to handle custom yaml conditional types.  Maps from conditional type
# to the function that performs the comparison.
CONDITIONALS={ FirstMaxYAML:FirstMax,
               FirstMinYAML:FirstMin,
               FirstTrueYAML:FirstTrue,
               LastTrueYAML:LastTrue}

########################################################################

def construct_ordered_dict(loader, node, deep=False):
    if not isinstance(node, MappingNode):
        raise ConstructorError(None, None,
                    "expected a mapping node, but found %s" % node.id,
                    node.start_mark)
    mapping = OrderedDict()
    loader.flatten_mapping(node)
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if not isinstance(key, collections.Hashable):
            raise ConstructorError("while constructing a mapping", node.start_mark,
                                   "found unhashable key", key_node.start_mark)
        value = loader.construct_object(value_node, deep=deep)
        mapping[key] = value
    return mapping

def add_yaml_ordered_dict(key,cls):
    """!Generates and registers representers and constructors for custom
    YAML map types    """
    def representer(dumper,data):
        return dumper.represent_ordered_dict(key,data)
    def constructor(loader,node):
        return cls(construct_ordered_dict(loader,node))
    #yaml.add_representer(cls,representer)
    yaml.add_constructor(key,constructor)

add_yaml_ordered_dict(u'!Eval',EvalYAML)
add_yaml_ordered_dict(u'!InputSlot',InputSlotYAML)
add_yaml_ordered_dict(u'!OutputSlot',OutputSlotYAML)
add_yaml_ordered_dict(u'!Clock',ClockYAML)
add_yaml_ordered_dict(u'!Cycle',CycleYAML)
add_yaml_ordered_dict(u'!Template',TemplateYAML)
add_yaml_ordered_dict(u'!Task',TaskYAML)
add_yaml_ordered_dict(u'!TaskArray',TaskArrayYAML)
add_yaml_ordered_dict(u'!TaskElement',TaskElementYAML)
add_yaml_ordered_dict(u'!DataEventElement',DataEventElementYAML)
add_yaml_ordered_dict(u'!ShellEventElement',ShellEventElementYAML)
add_yaml_ordered_dict(u'!Family',FamilyYAML)

SUITE={ EvalYAML: Eval,
        CycleYAML: Cycle,
        TemplateYAML: Template,
        TaskYAML: Task,
        DataEventYAML: DataEvent,
        ShellEventYAML: ShellEvent,
        FamilyYAML: Family,
        TaskArrayYAML: TaskArray,
        TaskElementYAML: TaskElement,
        DataEventElementYAML: DataEventElement,
        ShellEventElementYAML: ShellEventElement,
        ClockYAML:ClockMaker,
        OutputSlotYAML: OutputSlot,
        InputSlotYAML: InputSlot}

########################################################################

def valid_name(varname):
    """!Returns true if and only if the variable name is supported by this implementation."""
    return not varname.startswith('_')     and '-' not in varname and \
           not varname.endswith('_yaml')   and '.' not in varname and \
           not varname.startswith('yaml_')

class ConvertFromYAML(object):
    def __init__(self,tree,tools,ENV):
        self.memo=dict()
        self.result=None
        self.tree=tree
        self.tools=tools
        self.validatable=dict()
        self.immediates=dict()
        self.ENV=ENV

    def convert(self,validation_stage,evaluate_immediates):
        self.result=self.from_dict(self.tree,path='doc')
        globals={ 'tools':self.tools, 'doc':self.result, 'ENV': self.ENV }
        self.result._recursively_set_globals(globals)
        if evaluate_immediates:
            logger.debug('evaluate immediates')
            crow.config.eval_tools.evaluate_immediates(
                self.result,recurse=True)
        if validation_stage is not None:
            logger.debug(f'validate in {validation_stage}')
            crow.config.eval_tools.recursively_validate(
                self.result,validation_stage)
        else:
            logger.debug('do not validate')
        return self.result

    def to_eval(self,v,locals,path):
        """!Converts the object v to an internal implementation class.  If the
        conversion has already happened, returns the converted object
        from self.memo        """
        if id(v) not in self.memo:
            self.memo[id(v)]=self.to_eval_impl(v,locals,path=path)
        return self.memo[id(v)]

    def to_eval_impl(self,v,locals,path):
        """!Unconditionally converts the object v to an internal
        implementation class, without checking self.memo."""
        top=self.result
        # Specialized containers:
        cls=type(v)
        if cls in CONDITIONALS:
            return self.from_list(v,locals,CONDITIONALS[cls],path)
        elif cls in SUITE:
            return self.from_dict(v,SUITE[cls],path)
        elif cls is ImmediateYAML:
            return self.from_list(v,locals,Immediate,path)
        elif cls is InheritYAML:
            return self.from_list(v,locals,Inherit,path)
        elif cls is MergeMappingYAML:
            return self.from_list(v,locals,MergeMapping,path)
        elif cls is JobResourceSpecMakerYAML:
            return self.from_list(v,locals,JobResourceSpecMaker,path)
        elif isinstance(v,list) and v and isinstance(v[0],tuple) \
             or isinstance(v,OrderedDict):
            return self.from_ordered_dict(v,GenericOrderedDict,path)
        # Generic containers:
        elif isinstance(v,YAMLObject): return self.from_yaml(v,path=path)
        elif isinstance(v,dict):     return self.from_dict(v,path=path)
        elif isinstance(v,list):     return self.from_list(v,locals,path=path)
        elif isinstance(v,set):      return set(self.from_list(v,locals,path=path))
        elif isinstance(v,tuple):    return self.from_list(v,locals,path=path)

        # Scalar types:
        return v

    def from_yaml(self,yobj,path):
        """!Converts a YAMLObject instance yobj of a YAML, and its elements,
        to internal implementation types.  Elements with unsupported
        names are ignored.        """
        ret, cnv = type_for(yobj,path)
        for k in dir(yobj):
            if not valid_name(k): continue
            ret[k]=self.to_eval(getattr(yobj,k),ret,path=f'{path}.{k}')
        if cnv:
            kwargs=dict(ret)
            return cnv(**kwargs)
        self.validatable[id(ret)]=ret
        return ret

    def from_ordered_dict(self,tree,cls=GenericOrderedDict,path='doc'):
        assert(isinstance(cls,type))
        top=self.result
        ret=cls(OrderedDict(),path=path)
        for k,v in tree:
            if not valid_name(k): continue
            ret[k]=self.to_eval(v,ret,path=f'{path}.{k}')
        self.validatable[id(ret)]=ret
        return ret

    def from_dict(self,tree,cls=GenericDict,path='doc'):
        """!Converts an object yobj of a YAML standard map type, and its
        elements, to internal implementation types.  Elements with
        unsupported names are ignored.        """
        assert(isinstance(cls,type))
        top=self.result
        ret=cls(tree,path=path)
        for k,v in tree.items():
            if not valid_name(k): continue
            ret[k]=self.to_eval(v,ret,path=f'{path}.{k}')
        return ret

    def from_list(self,sequence,locals,cls=GenericList,path='doc'):
        """!Converts an object yobj of a YAML standard sequence type, and its
        elements, to internal implementation types.  Elements with
        unsupported names are ignored.  This is also used to handle
        other sequence-like types such as omap or set.        """
        assert(isinstance(cls,type))
        if hasattr(sequence,'__getitem__'):
            content=list()
            for i in range(len(sequence)):
                content.append(self.to_eval(
                    sequence[i],locals,f'{path}[{i}]'))
            return cls(content,locals,path)
        else:
            # For types that do not support indexing
            content=[self.to_eval(s,locals,path) for s in sequence]
            return cls(content,locals,path+'[*]')

