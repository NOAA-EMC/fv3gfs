"""!Internal representation classes for crow.config.  These handle the
embedded yaml calculations, as well as internal representations of all
custom data types in the yaml files."""

import re, abc, logging, sys, collections
from datetime import timedelta
from copy import deepcopy
from crow.config.exceptions import *
from crow.config.eval_tools import list_eval, dict_eval, multidict, from_config, strcalc
from crow.tools import to_timedelta, Clock
from copy import copy
import crow.sysenv

_logger=logging.getLogger('crow.config')

__all__=[ 'Action','Platform', 'Conditional', 'calc','FirstMin',
          'FirstMax', 'LastTrue', 'FirstTrue', 'GenericList',
          'GenericDict', 'GenericOrderedDict', 'ShellCommand',
          'Immediate', 'ClockMaker', 'JobResourceSpecMaker',
          'MergeMapping', 'Select' ]

########################################################################

class Action(dict_eval):
    """!Represents an action that a workflow should take, such as running
    a batch job."""
class GenericDict(dict_eval): pass
class GenericOrderedDict(dict_eval): pass
class GenericList(list_eval): pass
class Platform(dict_eval): pass
class ShellCommand(dict_eval): pass

class JobResourceSpecMaker(list_eval):
    def _result(self,globals,locals):
        rank_specs=list()
        for spec in self:
            if not hasattr(spec,'_raw_child'):
                rank_specs.append(spec)
                continue
            # Create a new dict_eval containing parent locals:
            spec2dict=copy(locals)
            spec2dict.update(spec._raw_child())
            spec2=dict_eval(spec2dict,spec._path,self._get_globals())

            # Get the value, from that new dict_eval, of all keys in spec.
            # Store it in the rank_specs list for the later constructor.
            rank_specs.append(dict([ (k,spec2[k]) for k in spec ]))
        return crow.sysenv.JobResourceSpec(rank_specs)

class ClockMaker(dict_eval):
    def _result(self,globals,locals):
        return Clock(start=self.start,step=self.step,
                     end=self.get('end',None),
                     now=self.get('now',None))
        
class Select(dict_eval):
    def _result(self,globals,locals):
        if 'select' not in self or 'otherwise' not in self or 'cases' not in self:
            raise KeyError(f'{self._path}: !Select must contain select, otherwise, and cases.')
        if not isinstance(self.cases,collections.Mapping):
            raise TypeError(f'{self._path}.cases: !Select cases must be a map')
        value=from_config('select',self._raw('select'),
                          globals,locals,self._path)
        if value in self.cases:
            if hasattr(self.cases,'_raw'):
                return self.cases._raw(value)
            return self.cases[value]
        return self._raw('otherwise')

class MergeMapping(list_eval):
    def _is_immediate(self): pass
    def _validate(self,*args,**kwargs): assert(False)
    def _result(self,globals,locals):
        result={}
        for d in self:
            if not isinstance(d,collections.Mapping): continue
            if not d: continue
            if hasattr(d,'_raw_child'):
                result.update(d._raw_child())
            else:
                result.update(d)
        result=dict_eval(result,self._path,self._get_globals())
        return result

class Immediate(list_eval): 
    def _result(self,globals,locals):
        return self[0]
    def _is_immediate(self): pass

class Conditional(list_eval):
    MISSING=object()
    def __init__(self,*args):
        super().__init__(*args)
        self.__result=Conditional.MISSING
    def _gather_keys_and_values(self,globals,locals):
        keys=list()
        values=list()
        otherwise_idx=Conditional.MISSING
        for i in range(len(self)):
            vk=self[i]
            has_otherwise = vk._has_raw('otherwise')
            has_when = vk._has_raw('when')
            has_do = vk._has_raw('do')
            if has_otherwise and ( has_when or has_do ):
                raise ConditionalOverspecified(
                    f'{self._path}[{i}]: cannot have "otherwise," '
                    '"when," and "do" in the same entry')
            elif has_otherwise and i!=len(self)-1:
                raise ConditionalInvalidOtherwise(
                    f'{self._path}[{i}]: "otherwise" must be the last item')
            elif has_otherwise:
                otherwise_idx=i
            elif has_when and has_do:
                values.append(vk._raw('do'))
                vk_locals=multidict(vk,locals)
                raw_when=vk._raw('when')
                keys.append(from_config('when',raw_when,globals,vk_locals,
                                        self._path))
            else:
                raise ConditionalMissingDoWhen(
                    f'{self._path}[{i}]: entries must have both "do" and "when"'
                    'or "otherwise" (or "message").  Saw keys: '+
                    ', '.join(list(vk.keys())))
        return keys, values, otherwise_idx

    def _result(self,globals,locals):
        assert('tools' in globals)
        assert('doc' in globals)
        ( keys, values, otherwise_idx ) = \
            self._gather_keys_and_values(globals,locals)
        if self._require_an_otherwise_clause() and \
           otherwise_idx is Conditional.MISSING:
            raise ConditionalMissingOtherwise(
                f'{self._path}: no "otherwise" clause provided')
        idx=self._index(keys)
        if idx is None:
            if otherwise_idx is Conditional.MISSING:
                raise ConditionalMissingOtherwise(
                    f'{self._path}: no clauses match and no '
                    f'"otherwise" value was given. {keys} {values}')
            self.__result=self[otherwise_idx]._raw('otherwise')
            _logger.debug(f'{self._path}: result=otherwise: {self.__result!r}')
            idx=otherwise_idx
        else:
            self.__result=values[idx]
            _logger.debug(f'{self._path}: result index {idx}: {self.__result!r}')
        if 'message' in self[idx]:
            message=from_config('message',self[idx].message,globals,locals,self._path)
            _logger.info(f'{self._path}[{idx}]: {message}')
        assert(self.__result is not Conditional.MISSING)
        return self.__result

    def _deepcopy_privates_from(self,memo,other):
        super()._deepcopy_privates_from(memo,other)
        if other.__result is Conditional.MISSING:
            self.__result=Conditional.MISSING
        else:
            self.__result=deepcopy(other.__result,memo)

    @abc.abstractmethod
    def _index(lst): pass

class FirstMax(Conditional):
    def _require_an_otherwise_clause(self): return False
    def _index(self,lst):
        return lst.index(max(lst)) if lst else None

class FirstMin(Conditional):
    def _require_an_otherwise_clause(self): return False
    def _index(self,lst):
        return lst.index(min(lst)) if lst else None

class LastTrue(Conditional):
    def _require_an_otherwise_clause(self): return True
    def _index(self,lst):
        for i in range(len(lst)-1,-1,-1):
            if lst[i]: return i
        return None

class FirstTrue(Conditional):
    def _require_an_otherwise_clause(self): return True
    def _index(self,lst):
        for i in range(len(lst)):
            if lst[i]: return i
        return None

class calc(strcalc): pass
