"""!Tools for handling inline python expression validation in YAML
objects.  In order to implement these inline expressions with
consistent and intuitive behavior, this module has to use some more
advanced features of Python, detailed below.

@note Basic python concepts in use

To develop or understand this file, you must be fluent in the
following basic Python concepts:

 * python built-in eval() function
 * MutableMapping and MutableSequence abstract base classes

@note Intermediate python concepts in use

To develop or understand this file, you must be fluent in the
following Python concepts:

 * operator specification (__getitem__, etc.)
 * default attributes (__getattr__)

@note Advanced python concept in use

Out of necessity, this file uses an advanced python feature.  To
develop or understand this file, you must be fluent in the use of this
feature:

 * custom locals in calls to eval()

"""

import logging
from collections.abc import MutableMapping, MutableSequence, Sequence, Mapping
from copy import copy,deepcopy
from crow.config.exceptions import *
from crow.tools import typecheck

__all__=[ 'expand', 'strcalc', 'from_config', 'dict_eval',
          'list_eval', 'multidict', 'Eval', 'user_error_message' ]
_logger=logging.getLogger('crow.config')

class user_error_message(str):
    """!Used to embed assertions in configuration code."""
    def _result(self,globals,locals):
        c=copy(globals)
        c['this']=locals
        raise ConfigUserError(eval("f'''"+self+"'''",c,locals))
    def _is_error(self): pass

class expand(str):
    """!Represents a literal format string."""
    def _result(self,globals,locals):
        if(self == '--{up}--'):
            assert('up' in locals)
        if "'''" in self:
            raise ValueError("!expand strings cannot include three single "
                             f"quotes in a row ('''): {self[:80]}")
        cmd=self
        if cmd[-1] == "'":
            cmd=cmd[:-1] + "\\" + cmd[-1]
        c=copy(globals)
        c['this']=locals
        return eval("f'''"+cmd+"'''",c,locals)

#f''''blah bla'h \''''

class strcalc(str):
    """Represents a string that should be run through eval()"""
    def __repr__(self):
        return '%s(%s)'%(type(self).__name__,
                         super().__repr__())
    def _result(self,globals,locals):
        c=copy(globals)
        c['this']=locals
        return eval(self,c,locals)

def from_config(key,val,globals,locals,path):
    """!Converts s strcalc cor Conditional to another data type via eval().
    Other types are returned unmodified."""
    try:
        if hasattr(val,'_result'):
            result=val._result(globals,locals)
            return from_config(key,result,globals,locals,path)
        return val
    except(KeyError,NameError,AttributeError) as ae:
        raise CalcKeyError(f'{path}: {type(val).__name__} {str(val)[0:80]} - '
                           f'{type(ae).__name__} {str(ae)} --in-- '
                           f'{{{", ".join([ k for k in locals.keys() ])}}}')
    except(SyntaxError,TypeError,IndexError) as ke:
        if 'f-string: unterminated string' in str(ke):
#            raise CalcKeyError(f'{path}: {type(val).__name__} 
            raise CalcKeyError(f'''{path}: {type(val).__name__}: probable unbalanced parentheses ([{{"''"}}]) in {str(val)[0:80]} {str(ke)[:80]}''')
        raise CalcKeyError(f'{path}: {type(val).__name__} {str(val)[0:80]} - '
                           f'{type(ke).__name__} {str(ke)[:80]}')
    except RecursionError as re:
        raise CalcRecursionTooDeep(
            f'{path}: !{key} {type(val).__name__}')

class multidict(MutableMapping):
    """!This is a dict-like object that makes multiple dicts act as one.
    Its methods look over the dicts in order, returning the result
    from the first dict that has a matching key.  This class is
    intended to be used in favor of a new dict, when the underlying
    dicts have special behaviors that are lost upon copy to a standard dict."""
    def __init__(self,*args):
        self.__dicts=list(args)
        self.__keys=frozenset().union(*args)
    def __len__(self):            return len(self.__keys)
    def __contains__(self,k):     return k in self.__keys
    def __copy__(self):           return multidict(self.__dicts)
    def __setitem__(self,k,v):    raise NotImplementedError('immutable')
    def __delitem__(self,k):      raise NotImplementedError('immutable')
    def _globals(self):
        """!Returns the global values used in eval() functions"""
        return self.dicts[0]._globals()
    def __contains__(self,key):
        for d in self.__dicts:
            if key in d:
                return True
        return False
    def __iter__(self):
        for k in self.__keys: yield k
    def __getitem__(self,key):
        for d in self.__dicts:
            if key in d:
                return d[key]
        raise KeyError(key)
    def _raw(self,key):
        """!Returns the raw value of the given key without calling eval()"""
        for d in self.__dicts:
            if key in d:
                return d._raw(key)
        raise KeyError(key)
    def _has_raw(self,key):
        try:
            self._raw(key)
            return True
        except KeyError: return False
    def _expand_text(self,text):
        eval("f'''"+text+"'''",self._globals(),self)
    def __repr__(self):
        return '%s(%s)'%(
            type(self).__name__,
            ','.join([repr(d) for d in self.__dicts]))
    def __str__(self):
        return '{'+', '.join([f'{k}:{v}' for k,v in self])+'}'

########################################################################

class dict_eval(MutableMapping):
    """!This is a dict-like object that knows how to eval() its contents,
    passing this dict as the local arguments.  This allows one to
    store actions like the following:

    * \c a = b + c

    where a, b, and c are elements of dict_eval.  The result of
    __getitem__(a) is then the result of:

    * __getitem__(b) + __getitem__(c)    """

    def __init__(self,child,path='',globals=None):
        #assert(not isinstance(child,dict_eval))
        typecheck('child',child,Mapping)
        self.__child=copy(child)
        self.__cache=copy(child)
        self.__globals={} if globals is None else globals
        self.__is_validated=False
        self._path=path
    def __contains__(self,k):   return k in self.__child
    def __len__(self):          return len(self.__child)
    def __copy__(self):
        cls=type(self)
        d=cls(self.__child,self._path)
        d.__globals=self.__globals
        return d

    def _invalidate_cache(self,key=None):
        _logger.debug(f'{self._path}: invalidate cache')
        self._is_validated=False
        if key is None:
            #print(f'{self._path}: reset')
            self.__cache=copy(self.__child)
            #if 'ecflow_def' in self:
            #    print(f'ecflow_def = {self.__cache["ecflow_def"]!r}')
        else:
            self.__cache[key]=self.__child[key]
    def _raw_child(self):       return self.__child
    def _has_raw(self,key):     return key in self.__child
    def _iter_raw(self):
        for v in self.__child.values():
            yield v
    def _set_globals(self,g):   self.__globals=g
    def _get_globals(self):     return self.__globals
    def _raw_cache(self):       return self.__cache
    def _raw(self,key):
        """!Returns the value for the given key, without calling eval() on it"""
        return self.__child[key]
    def _globals(self):
        """!Returns the global values used in eval() functions"""
        return self.__globals
    def _expand_text(self,text):
        return eval('f'+repr(text),self.__globals,self)
    def _deepcopy_child(self,memo):
        cls=type(self.__child)
        return deepcopy(self.__child,memo)
    def _deepcopy_privates_from(self,memo,other):
        self.__globals=deepcopy(other.__globals,memo)
#dict([ ( deepcopy(k,memo),deepcopy(v,memo) )
#                              for k,v in other.__globals.items() ])
        self.__cache=deepcopy(other.__cache,memo)
        self._path=deepcopy(other._path,memo)
        self.__is_validated=deepcopy(other.__is_validated,memo)
        #self.__globals=deepcopy(other.__globals,memo)
    def __deepcopy__(self,memo):
        cls=type(self)
        r=cls(type(self.__child)())
        memo[id(self)]=r
        r.__child=self._deepcopy_child(memo)
        r._deepcopy_privates_from(memo,self)
        return r
    def __setitem__(self,k,v):  
        if 'final' in self._path and k=='Rocoto':
            assert(isinstance(v,expand))
        self.__child[k]=v
        self.__cache[k]=v
    def __delitem__(self,k): del(self.__child[k], self.__cache[k])
    def __iter__(self):
        for k in self.__child.keys(): yield k
    def _validate(self,stage,memo=None):
        """!Validates this dict_eval using its embedded Template object, if present """
        if self.__is_validated: return
        self.__is_validated=True

        # Make sure we don't get infinite recursion:
        if memo is None: memo=set()
        if id(self) in memo:
            raise ValidationRecursionError(
                f'{self._path}: cyclic Inherit detected')
        memo.add(id(self))

        # Inherit from other scopes:
        if 'Inherit' in self:
            _logger.debug(f'{self._path}: has Inherit')
            if hasattr(self.Inherit,'_update'):
                self.Inherit._update(self,self.__globals,self,stage,memo)
                _logger.debug(f'{self._path}: after inherit, {{{", ".join([k for k in self.keys()])}}}')
            else:
                _logger.warning(f'{self._path}: Inherit is not an !Inherit.  Error?')
        else:
            _logger.debug(f'{self._path}: no Inherit')

        # Validate this scope:
        if 'Template' in self:
            tmpl=self.Template
            if not tmpl: return
            if isinstance(tmpl,str): return
            if isinstance(tmpl,Sequence):
                templates=tmpl
            else:
                templates=[ tmpl ]
            for tmpl in templates:
                if not isinstance(tmpl,Mapping): continue
                if not hasattr(tmpl,'_check_scope'):
                    tmpl=Template(tmpl,self._path+'.Template',self.__globals)
                tmpl._check_scope(self,stage,memo)
    def __getitem__(self,key):
        if key not in self.__cache:
            if key not in self.__child:
                raise KeyError(f'{self._path}: no {key} in {list(self.keys())}')
            self.__cache[key]=self.__child[key]
        val=self.__cache[key]
        if hasattr(val,'_result'):
            immediate=hasattr(val,'_is_immediate')
            val=from_config(key=key,val=val,globals=self.__globals,locals=self,
                            path=f'{self._path}.{key}')
            self.__cache[key]=val
            if immediate:
                self.__child[key]=val
        return val
    def __getattr__(self,name):
        if name in self: return self[name]
        raise AttributeError(f'{self._path}: no {name} in {list(self.keys())}')
    def __setattr__(self,name,value):
        if name.startswith('_'):
            object.__setattr__(self,name,value)
        else:
            self[name]=value
    def __delattr__(self,name):
        del self[name]
    def _to_py(self,recurse=True):
        """!Converts to a python core object; does not work for cyclic object trees"""
        cls=type(self.__child)
        return cls([(k, to_py(v)) for k,v in self.items()])
    def _child(self): return self.__child
    def _recursively_set_globals(self,globals,memo=None):
        """Recurses through the object tree setting the globals for eval() calls"""
        assert('tools' in globals)
        assert('doc' in globals)
        if memo is None: memo=set()
        if id(self) in memo: return
        memo.add(id(self))
        if self.__globals is globals: return
        self.__globals=globals
        for k,v in self.__child.items():
            try:
                v._recursively_set_globals(globals,memo)
            except AttributeError: pass
    def __repr__(self):
        return '%s(%s)'%(type(self).__name__,repr(self.__child),)
    def __str__(self):
        return '{'+', '.join([f'{k}={v}' for k,v in self.items()])+'}'

########################################################################

class list_eval(MutableSequence):
    """!This is a dict-like object that knows how to eval() its contents,
    passing a containing dict as the local arguments.  The parent
    dict-like object is passed as the locals argument of the
    constructor.  This class allows one to store actions like the
    following:

    * \c a = [ b+c, b-c ]

    where a, b, and c are elements of the parent dict.  The result of
    __getitem__(a) is then the result of:

    \code
    [ self.__locals.__getitem__(b) + self.__locals.__getitem__(c),
      self.__locals.__getitem__(b) - self.__locals.__getitem__(c) ]
    \endcode    """
    def __init__(self,child,locals,path=''):
        typecheck('child',child,Sequence)
        self.__child=list(child)
        self.__cache=list(child)
        self.__locals=locals
        self.__globals={}
        self._path=path
    def _raw_cache(self):       return self.__cache
    def __len__(self):          return len(self.__child)
    def _get_globals(self):     return self.__globals
    def _set_globals(self,g):   self.__globals=g
    def _get_locals(self):      return self.__locals
    def _iter_raw(self):
        for v in self.__child:
            yield v
    def _raw_child(self):       return self.__child
    def _raw(self,i):           
        """!Returns the value at index i without calling eval() on it"""
        return self.__child[i]
    def _has_raw(self,i):
        return i>=0 and len(self.__child)>i
    def __copy__(self):
        cls=type(self)
        L=cls(copy(self.__child),self.__locals)
        L.__globals=self.__globals
        return L
    def __deepcopy__(self,memo):
        cls=type(self)
        r=cls([],{})
        memo[id(self)]=r
        r._deepcopy_privates_from(memo,self)
        return r
    def _deepcopy_privates_from(self,memo,other):
        self.__child=deepcopy(other.__child,memo)
        self.__cache=deepcopy(other.__cache,memo)
        self._path=deepcopy(other._path)
        self.__globals=deepcopy(other.__globals,memo)
        self.__cache=deepcopy(other.__cache,memo)
    def _invalidate_cache(self,index=None):
        _logger.debug(f'{self._path}: invalidate cache')
        if index is None:
            self.__cache=copy(self.__child)
        else:
            self.__cache[key]=self.__child[key]
    def __setitem__(self,k,v):
        self.__child[k]=v
        self.__cache[k]=v
    def __delitem__(self,k):
        del(self.__child[k], self.__cache[k])
    def insert(self,i,o):
        self.__child.insert(i,o)
        self.__cache.insert(i,o)
    def __getitem__(self,index):
        val=self.__cache[index]
        if hasattr(val,'_result'):
            immediate=hasattr(val,'_is_immediate')
            val=from_config(index,val,self.__globals,self.__locals,
                            f'{self._path}[{index}]')
            self.__cache[index]=val
            if immediate:
                self.__child[index]=val
        assert(val is not self)
        return val
    def _to_py(self,recurse=True):
        """!Converts to a python core object; does not work for cyclic object trees"""
        return [ to_py(v) for v in self ]
    def _recursively_set_globals(self,globals,memo):
        if memo is None: memo=set()
        if id(self) in memo: return
        memo.add(id(self))
        if self.__globals is globals: return
        self.__globals=globals
        for v in self.__child:
            if isinstance(v,dict_eval) or isinstance(v,list_eval):
                v._recursively_set_globals(globals,memo)
    def __repr__(self):
        return '%s(%s)'%(type(self).__name__,repr(self.__child),)
    def __str__(self):
        return '['+', '.join([str(v) for v in self])+']'
    def __eq__(self,other):
        if not isinstance(other,Sequence): return False
        my_len=len(self)
        if my_len != len(other): return False
        for i in range(my_len):
            if self[i] != other[i]: return False
        return True

########################################################################

class Eval(dict_eval):
    def _result(self,globals,locals):
        if 'result' not in self:
            raise EvalMissingCalc('"!Eval" block lacks a "result: !calc"')
        return self.result

def update_globals(s,globals):
    gcopy=dict(s._get_globals())
    doc=gcopy['doc']
    tools=gcopy['tools']
    gcopy.update(globals)
    gcopy['doc']=doc
    gcopy['tools']=tools
    doc._recursively_set_globals(gcopy)

def recursively_validate(obj,stage,validation_memo=None,inheritence_memo=None):
    if validation_memo is None: validation_memo=set()
    if id(obj) in validation_memo: return
    validation_memo.add(id(obj))

    if hasattr(obj,'_validate'):
        obj._validate(stage)
    if hasattr(obj,'_iter_raw'):
        for subobj in obj._iter_raw():
            recursively_validate(subobj,stage,validation_memo,inheritence_memo)

def _invalidate_cache_one_obj(obj,key=None):
    if hasattr(obj,'_invalidate_cache'):
        #print(f'invalidate cache {obj.path}')
        obj._invalidate_cache(key)

def _recursively_invalidate_cache(obj,memo):
    #print('invalidate cache rec')
    if id(obj) in memo: return
    memo.add(id(obj))
    _invalidate_cache_one_obj(obj)
    if hasattr(obj, '_iter_raw' ):
        #print('iter raw in obj')
        for r in obj._iter_raw():
            _recursively_invalidate_cache(r,memo)
    else:
        pass
        #print(f'no _iter_raw in obj of type {type(obj).__name__}')

def invalidate_cache(obj,key=None,recurse=False):
    #print(f'invalidate cache {key} {recurse}')
    _invalidate_cache_one_obj(obj,key)
    if recurse:
        #print('in recurse')
        if key is not None: obj=obj[key]
        _recursively_invalidate_cache(obj,set())

def evaluate_one(obj,key,val,memo):
    if hasattr(val,'_is_immediate'):
        if memo is not None:
            evaluate_immediates_impl(obj[key],memo)
        else:
            _ = obj[key]
    elif not hasattr(val,'_result') and memo is not None:
        evaluate_immediates_impl(obj[key],memo)

def evaluate_immediates_impl(obj,memo=None):
    if memo is not None:
        if id(obj) in memo: return
        memo.add(id(obj))

    if hasattr(obj,'_raw_child'):
        child=obj._raw_child()
    else:
        child=obj

    if hasattr(child,'items'):       # Assume mapping.
        if 'Evaluate' in child and not child['Evaluate']:
            return # Scope requested no evaluation.
        for k,v in child.items():
            evaluate_one(obj,k,v,memo)
    elif hasattr(child,'index'):     # Assume sequence.
        for i in range(len(child)):
            evaluate_one(obj,i,child[i],memo)

def evaluate_immediates(obj,recurse=False):
    if hasattr(obj,'_result'):
        return
    memo=set() if recurse else None
    evaluate_immediates_impl(obj,memo)

from crow.config.template import Template
