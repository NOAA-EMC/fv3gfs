import yaml
import sys, logging
from yaml.nodes import MappingNode, ScalarNode, SequenceNode
from copy import copy
from collections import OrderedDict
from collections.abc import Mapping
from crow.tools import Clock
from crow.config.eval_tools import *
from crow.config.represent import *
from crow.config.tasks import *
from crow.config.template import Template, Inherit
from crow.config.exceptions import *
from crow.tools import to_timedelta, typecheck

import crow.sysenv

# We need to run the from_yaml module first, to initialize the yaml
# representers for some types.  This module does not actually use any
# symbols from from_yaml; only execution of that module is needed.
import crow.config.from_yaml

_logger=logging.getLogger('crow.config')

def to_yaml(yml):
    if hasattr(yml,'_raw_cache'):
        yml=copy(yml._raw_child())
    return yaml.dump(yml)

########################################################################

def add_yaml_list_eval(key,cls): 
    def representer(dumper,data):
        if key is None:
            return dumper.represent_data(data._raw_child())
        else:
            return dumper.represent_sequence(key,data._raw_child())
    yaml.add_representer(cls,representer)

add_yaml_list_eval(u'!FirstMax',FirstMax)
add_yaml_list_eval(u'!FirstMin',FirstMin)
add_yaml_list_eval(u'!LastTrue',LastTrue)
add_yaml_list_eval(u'!FirstTrue',FirstTrue)
add_yaml_list_eval(u'!Immediate',Immediate)
add_yaml_list_eval(u'!JobRequest',JobResourceSpecMaker)
add_yaml_list_eval(u'!Inherit',Inherit)
add_yaml_list_eval(u'!MergeMapping',MergeMapping)
add_yaml_list_eval(None,GenericList)

########################################################################

def add_yaml_dict_eval(key,cls): 
    """!Generates and registers a representer for a custom YAML mapping
    type    """
    def representer(dumper,data):
        assert('up' not in data)
        typecheck('data',data,Mapping)
        raw_data=data._raw_child()
        typecheck('data._raw_child()',raw_data,Mapping)
        try:
            if key is None:
                return dumper.represent_data(raw_data)
            else:
                return dumper.represent_mapping(key,raw_data)
        except(IndexError,TypeError,ValueError) as e:
            _logger.error(f'{data._path}: cannot represent: {e} (key={key})')
            raise
    yaml.add_representer(cls,representer)

add_yaml_dict_eval(None,GenericDict)
add_yaml_dict_eval(u'!Platform',Platform)
add_yaml_dict_eval(u'!Select',Select)
add_yaml_dict_eval(u'!Action',Action)
add_yaml_dict_eval(u'!Eval',Eval)
add_yaml_dict_eval(u'!InputSlot',InputSlot)
add_yaml_dict_eval(u'!OutputSlot',OutputSlot)

########################################################################

def represent_ordered_mapping(dumper, tag, mapping, flow_style=None):
    value = []
    node = MappingNode(tag, value, flow_style=flow_style)
    if dumper.alias_key is not None:
        dumper.represented_objects[dumper.alias_key] = node
    best_style = True
    if hasattr(mapping, 'items'):
        mapping = list(mapping.items())
    for item_key, item_value in mapping:
        node_key = dumper.represent_data(item_key)
        node_value = dumper.represent_data(item_value)
        if not (isinstance(node_key, ScalarNode) and not node_key.style):
            best_style = False
        if not (isinstance(node_value, ScalarNode) and not node_value.style):
            best_style = False
        value.append((node_key, node_value))
    if flow_style is None:
        if dumper.default_flow_style is not None:
            node.flow_style = dumper.default_flow_style
        else:
            node.flow_style = best_style
    return node

########################################################################

NONE=object()

def add_yaml_taskable(key,cls): 
    """!Generates and registers a representer for a custom YAML mapping
    type    """
    def representer(dumper,data):
        simple=data._raw_cache()
        up=simple['up'] if 'up' in simple else NONE
        if up is not NONE: del simple['up']
        if not isinstance(simple,OrderedDict):
            simple=OrderedDict([ (k,v) for k,v in simple.items() ])
        rep=represent_ordered_mapping(dumper,key,simple)
        if up is not NONE: simple['up']=up
        return rep
    yaml.add_representer(cls,representer)

add_yaml_taskable(u'!DataEvent',DataEvent)
add_yaml_taskable(u'!ShellEvent',ShellEvent)
add_yaml_taskable(u'!Task',Task)
add_yaml_taskable(u'!Family',Family)
add_yaml_taskable(u'!TaskArray',TaskArray)
add_yaml_taskable(u'!TaskElement',TaskElement)
add_yaml_taskable(u'!ShellEventElement',ShellEventElement)
add_yaml_taskable(u'!DataEventElement',DataEventElement)
add_yaml_taskable(u'!Cycle',Cycle)
add_yaml_taskable(u'!Template',Template)

########################################################################

def add_yaml_suite_view(key,cls): 
    """!Generates and registers a representer for a custom YAML mapping
    type    """
    def representer(dumper,data):
        d=data.viewed._raw_child()
        up=d['up']
        del d['up']
        assert('up' not in d)
        rep=dumper.represent_ordered_mapping(dumper,key,d)
        d['up']=up
        return rep
    yaml.add_representer(cls,representer)

add_yaml_suite_view(u'!Task',TaskView)
add_yaml_suite_view(u'!Family',FamilyView)
add_yaml_suite_view(u'!Cycle',CycleView)
add_yaml_suite_view(u'!Cycle',Suite)

########################################################################

def represent_omap(dumper, mapping, flow_style=None):
    value = []
    tag = 'tag:yaml.org,2002:omap'

    node = SequenceNode(tag, value, flow_style=flow_style)

    if dumper.alias_key is not None:
        dumper.represented_objects[dumper.alias_key] = node
    best_style = True
    for item_key, item_value in mapping.items():
        node_key = dumper.represent_data(item_key)
        node_value = dumper.represent_data(item_value)
        subnode = MappingNode('tag:yaml.org,2002:map', [ ( node_key,node_value ) ])
        value.append(subnode)
    node.flow_style = True
    return node

yaml.add_representer(GenericOrderedDict,represent_omap)

########################################################################

def represent_JobResourceSpec(dumper,data):
    return dumper.represent_sequence('!JobRequest',list(data))
yaml.add_representer(crow.sysenv.JobResourceSpec,
                     represent_JobResourceSpec)

def represent_JobRankSpec(dumper,data):
    return dumper.represent_data(dict(data))
yaml.add_representer(crow.sysenv.JobRankSpec,represent_JobRankSpec)

########################################################################

def represent_Clock(dumper,data):
    mapping={ 'start':data.start, 'step':data.step }
    if data.end is not None:   mapping['end']=data.end
    if data.now!=data.start:   mapping['now']=data.now
    return dumper.represent_mapping('!Clock',mapping)
yaml.add_representer(Clock,represent_Clock)

def represent_ClockMaker(dumper,data):
    while hasattr(data,'_raw_child'):
        data=data._raw_child()
    return dumper.represent_mapping('!Clock',data)
yaml.add_representer(ClockMaker,represent_ClockMaker)
