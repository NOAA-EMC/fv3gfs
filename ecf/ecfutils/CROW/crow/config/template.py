"""!Validation logic for YAML mapping types via the "!Template" YAML
type.

@note Intermediate python concepts in use

To develop or understand this file, you must be fluent in the
following intermediate Python concepts:

- treating types as objects
- treating functions as objects

"""

import re, sys, logging
from copy import copy
from collections import OrderedDict
from datetime import timedelta, datetime
from crow.config.exceptions import *
from crow.config.eval_tools import list_eval, dict_eval, multidict, from_config
from crow.config.represent import GenericList, GenericDict, GenericOrderedDict
from collections.abc import Mapping

_logger=logging.getLogger('crow.config')
IGNORE_WHILE_INHERITING = [ 'Inherit', 'Template' ]

class Inherit(list_eval): 
    def _update(self,target,globals,locals,stage,memo):
        errors=list()
        for scopename,regex in reversed(self):
            inherited=False
            try:
                scopename=str(scopename)
                _logger.debug(f'{target._path}: inherit from {scopename}')
                scope=eval(scopename,globals,locals)
                if hasattr(scope,'_validate'):
                    scope._validate(stage,memo)
                for key in scope:
                    if key not in IGNORE_WHILE_INHERITING  and \
                       re.search(regex,key) and key not in target:
                        inherited=True
                        _logger.debug(f'{target._path}: inherit {key} from {scopename} regex {regex}')
                        target._raw_child()[key]=scope._raw_child()[key]
            # except (IndexError,AttributeError,TypeError,ValueError) as pye:
            #     msg=f'{target._path}: when including {scope._path}:'\
            #          f'{type(pye).__name__}: {pye}'
            #     errors.append(msg)
            #     _logger.debug(msg,exc_info=True)
            except TemplateErrors as te:
                errors.append(f'{target._path}: when including {scope._path}')
                errors.extend(te.template_errors)
            if not inherited:
                _logger.debug(f'{target._path}: inherit nothing from {scopename} with regex {regex} keys {{{", ".join([k for k in scope.keys()])}}}')
        if errors: raise TemplateErrors(errors)
        _logger.debug(f'{target._path}: now has keys {{{", ".join([k for k in target.keys()])}}}')

class Template(dict_eval):
    """!Internal implementation of the YAML Template type.  Validates a
    dict_eval, inserting defaults and reporting errors via the
    TemplateErrors exception.    """
    def __init__(self,child,path='',globals=None):
        self.__my_id=id(child)
        super().__init__(child,path,globals)

    def _check_scope(self,scope,stage,memo):
        if self.__my_id in memo:
            _logger.debug(f'{scope._path}: do not re-validate with {self._path}')
            return
        memo.add(self.__my_id)

        _logger.debug(f'{scope._path}: validate with {self._path}')

        checked=set()
        errors=list()
        template=copy(self)
        did_something=True

        # Main validation loop.  Iteratively validate, adding new
        # Templates as they become available via is_present.
        for var in template:
            _logger.debug(f'{scope._path}.{var}: validate...')
            try:
                scheme=template[var]
                if not isinstance(scheme,Mapping): continue # not a template
                if stage and 'stages' in scheme:
                    if stage not in scheme.stages:
                        continue # skip validation; wrong stage
                elif 'stages' in scheme:
                    continue # skip validation of stage-specific schemes

                if 'precheck' in scheme:
                    scope[var]=scheme.precheck
                    
                if var in scope:
                    validate_var(scope._path,scheme,var,scope[var])
                elif 'default' in scheme:
                    scope[var]=from_config(
                        var,scheme._raw('default'),self._globals(),scope,
                        f'{scope._path}.{var}')
                    _logger.debug(f'{scope._path}.{var}: insert default {scope._raw(var)}')
                if var not in scope and 'if_present' in scheme:
                    _logger.debug(f'{scope._path}.{var}: not present; skip if_present')
                if var in scope and 'if_present' in scheme:
                    _logger.debug(f'{scope._path}.{var}: evaluate if_present '
                                  f'{scheme._raw("if_present")._path}')
                    ip=from_config(
                        var,scheme._raw('if_present'),self._globals(),scope,
                        f'{scope._path}.{var}')
                    _logger.debug(f'{scope._path}.{var}: result = {ip!r}')
                    if not ip: continue
                    if not isinstance(ip,Template):
                        if not isinstance(ip,Mapping): continue
                        ip=Template(ip._raw_child(),ip._path,ip._get_globals())
                    _logger.debug(
                        f'{scope._path}.{var}: present ({scope._raw(var)!r}); '
                        f'add {ip._path} to validation')
                    ip._check_scope(scope,stage,memo)

                if 'override' in scheme:
                    override=from_config(
                        'override',template[var]._raw('override'),
                        scope._globals(),scope,
                        f'{scope._path}.Template.{var}.override')
                    if override is not None: scope[var]=override

            except (IndexError,AttributeError,TypeError,ValueError) as pye:
                errors.append(f'{scope._path}.{var}: {type(pye).__name__}: {pye}')
                _logger.debug(f'{scope._path}.{var}: {pye}',exc_info=True)
            except ConfigError as ce:
                errors.append(str(ce))
                _logger.debug(f'{scope._path}.{var}: {type(ce).__name__}: {ce}',exc_info=True)


        # Insert default values for all templates found thus far and
        # detect any missing, non-optional, variables
        missing=list()
        for var in template:
            if var not in scope:
                tmpl=template[var]
                if not hasattr(tmpl,'__getitem__') or not hasattr(tmpl,'update'):
                    raise TypeError(f'{self._path}.{var}: All entries in a !Template must be maps not {type(tmpl).__name__}')
                if 'default' not in tmpl and not tmpl.get('optional',False):
                    missing.append(var)

        # Second pass checking for required variables that have no
        # values.  This second pass deals with variables that were
        # updated by an "override" clause.
        reported_missing=set(missing)
        in_scope=set([k for k in scope.keys()])
        still_missing=reported_missing-in_scope
        if still_missing:
            raise VariableMissing(f'{scope._path}: missing: '+
                                  ', '.join(still_missing)+' in: '+
                                  ', '.join([k for k in scope.keys()]))

        # Check for variables that evaluate to an error
        for key,expr in scope._raw_child().items():
            if hasattr(expr,'_is_error'):
                try:
                    scope[key]
                except ConfigUserError as ce:
                    errors.append(f'{scope._path}.{key}: {ce}')

        if errors: raise TemplateErrors(errors)

class TemplateValidationFailed(object):
    """!Used for constants that represent validation failure cases"""
    def __bool__(self):         return False

NOT_ALLOWED=TemplateValidationFailed()
TYPE_MISMATCH=TemplateValidationFailed()
UNKNOWN_TYPE=TemplateValidationFailed()

def validate_scalar(types,val,allowed,tname):
    """!Validates val against the type tname, and allowed values.  Forbids
    recursion (scalars cannot contain subobjects."""
    if allowed and val not in allowed:    return NOT_ALLOWED
    if len(types):                        return TYPE_MISMATCH
    for cls in TYPES[tname]:
        if isinstance(val,cls): return True
    return TYPE_MISMATCH

def validate_list(types,val,allowed,tname):
    """!Valdiates that val is a list that contains the specified allowed
    values.  Recurses into subobjects, which must be of type types[-1] """
    if not len(types):                     return TYPE_MISMATCH
    if type(val) not in TYPES[tname]: raise Exception('unknown type')
    for v in val:
        result=VALIDATORS[types[-1]](types[:-1],v,allowed,types[-1])
        if not result: return result
    return True

def validate_dict(types,val,allowed,typ):
    """!Valdiates that val is a map that contains the specified allowed
    values.  Recurses into subobjects, which must be of type types[-1] """
    if not len(types):                    return TYPE_MISMATCH
    if str(type(val)) not in typ['list']: raise(Exception('unknown type'))
    for k,v in val.items():
        result=VALIDATORS[types[-1]](types[:-1],v,allowed,types[-1])
        if not result: return result
    return True

## @var TYPES
# Mapping from YAML type to valid python types.
TYPES={ 'int':[int], 'bool':[bool], 'string':[str,bytes],
        'float':[float], 'list':[set,list,tuple,list_eval,GenericList],
        'dict':[dict,dict_eval,GenericDict,GenericOrderedDict],
        'seq':[set,list,tuple,list_eval,GenericList],
        'timedelta':[timedelta],'datetime':[datetime] }

## @var VALIDATORS
# Mapping from YAML type to validation function.
VALIDATORS={ 'map':validate_dict,     
             'seq':validate_list,
             'list':validate_list,
             'set':validate_list,
             'int':validate_scalar,
             'bool':validate_scalar,
             'string':validate_scalar,
             'datetime':validate_scalar,
             'float':validate_scalar,
             'timedelta': validate_scalar}

def validate_type(path,var,typ,val,allowed):
    """!Top-level validation function.  Checks that the value val of the
    variable var is of the given type typ and has values in the list
    of those allowed.    """
    types=typ.split()
    for t in types:
        if t not in VALIDATORS:
            raise InvalidConfigType(
                f'{path}.{var}={t!r}: unknown type in {typ!r}')
    result=VALIDATORS[types[-1]](types[:-1],val,allowed,types[-1])
    if result is UNKNOWN_TYPE:
        raise InvalidConfigType(
            f'{path}.{var}={t!r}: unknown type in {typ!r}')
    elif result is TYPE_MISMATCH:
        val_repr='null' if val is None else repr(val)
        raise InvalidConfigValue(
            f'{path}.{var}={val_repr}: not valid for type {typ!r}'
            '.  Should this have been a !calc?')
    elif result is NOT_ALLOWED:
        val_repr='null' if val is None else repr(val)
        raise InvalidConfigValue(
            f'{path}.{var}={val_repr}: not an allowed value ('
            f'{", ".join([repr(s) for s in allowed])})')

def validate_var(path,scheme,var,val):
    """!Main entry point to recursive validation system.  Validates
    variable var with value val against the YAML Template list item in
    scheme.    """
    if 'type' not in scheme:
        raise InvalidConfigTemplate(var+'.type: missing')
    typ=scheme.type
    if not isinstance(typ,str):
        raise InvalidConfigTemplate(var+'.type: must be a string')
    allowed=scheme.get('allowed',[])
    if not isinstance(allowed,list) and not isinstance(allowed,list_eval):
        raise InvalidConfigTemplate(var+'.allowed: must be a list')
    validate_type(path,var,typ,val,allowed)

