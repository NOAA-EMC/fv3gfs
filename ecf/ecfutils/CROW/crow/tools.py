import subprocess, os, re, logging, tempfile, datetime, shutil, math
from datetime import timedelta
from copy import deepcopy, copy
from contextlib import suppress, contextmanager
from collections.abc import Mapping

__all__=['panasas_gb','gpfs_gb','to_timedelta','deliver_file','NamedConstant',
         'Clock','str_timedelta','memory_in_bytes','to_printf_octal',
         'str_to_posix_sh','typecheck','ZER_DT','shell_to_python_type',
         'MISSING','chdir']

_logger=logging.getLogger('crow.tools')

@contextmanager
def chdir(dir):
    olddir=os.getcwd()
    os.chdir(dir)
    yield
    os.chdir(olddir)

def deliver_file(from_file: str,to_file: str,*,blocksize: int=1048576,
                 permmask: int=2,preserve_perms: bool=True,
                 preserve_times: bool=True,preserve_group: bool=True,
                 mkdir: bool=True) -> None:
    to_dir=os.path.dirname(to_file)
    to_base=os.path.basename(to_file)
    if mkdir and to_dir and not os.path.isdir(to_dir):
        _logger.info(f'{to_dir}: makedirs')
        os.makedirs(to_dir)
    temppath=None # type: str
    _logger.info(f'{to_file}: deliver from {from_file}')
    try:
        with open(from_file,'rb') as in_fd:
            istat=os.fstat(in_fd.fileno())
            with tempfile.NamedTemporaryFile(
                    prefix=f"_tmp_{to_base}.part.",
                    delete=False,dir=to_dir) as out_fd:
                temppath=out_fd.name
                shutil.copyfileobj(in_fd,out_fd,length=blocksize)
        assert(temppath)
        assert(os.path.exists(temppath))
        if preserve_perms:
            os.chmod(temppath,istat.st_mode&~permmask)
        if preserve_times:
            os.utime(temppath,(istat.st_atime,istat.st_mtime))
        if preserve_group:
            os.chown(temppath,-1,istat.st_gid)
        os.rename(temppath,to_file)
        temppath=None
    except Exception as e:
        _logger.warning(f'{to_file}: {e}')
        raise
    finally: # Delete file on error
        if temppath and os.path.exists(temppath): os.unlink(temppath)

def panasas_gb(dir,pan_df='pan_df'):
    rdir=os.path.realpath(dir)
    stdout=subprocess.check_output([pan_df,'-B','1G','-P',rdir])
    result=0
    for line in stdout.splitlines():
        if rdir in str(line):
            result=int(line.split()[3],10)
    _logger.info(f'{pan_df} of {dir} is {result}')
    return result
#pan_df -B 1G -P /scratch4/NCEPDEV/stmp3/
#Filesystem         1073741824-blocks      Used Available Capacity Mounted on
#panfs://10.181.12.11/     94530     76432     18098      81% /scratch4/NCEPDEV/stmp3/

def gpfs_gb(dir,fileset,device,mmlsquota='mmlsquota'):
    mmlsquota=subprocess.check_output([
        mmlsquota, '--block-size', '1T','-j',fileset,device])
    for m in re.finditer(b'''(?isx)
               (?:
                   (?P<device>\S+) \s+ FILESET
                   \s+ (?P<TBused>  \d+  )
                   \s+ (?P<TBquota> \d+  )
                   \s+ (?P<TBlimit> \d+  )
                   [^\r\n]* (?: [\r\n] | [\r\n]*\Z )
                |
                 (?P<bad> [^\r\n]*[\r\n] | [^\r\n]*\Z )
               )
               ''',mmlsquota):
        
        if m.group('bad') or not m.group('TBused') \
           or not m.group('TBlimit'):
            continue
        result=1024*(int(m.group('TBlimit')) - int(m.group('TBused')))
        _logger.info(f'{device}:{fileset}: space={result}')
        return result
    _logger.error(f'{device}:{fileset}: not found or no quota')
    return 0
    
class ImmutableMapping(Mapping):
    """Immutable dictionary"""

    def __deepcopy__(self,memo):
        im=ImmutableMapping()
        im.__dict=dict([ (deepcopy(k),deepcopy(v)) \
                         for k,v in self.__dict.items() ])
        return im
    def __init__(self,*args,**kwargs): self.__dict=dict(*args,**kwargs)
    def __len__(self):                 return len(self.__dict)
    def __getitem__(self,k):           return self.__dict[k]
    def __getattr__(self,name):        return self[name]
    def __iter__(self):
        for i in self.__dict:
            yield i



########################################################################

DT_REGEX={
    u'(\d+):(\d+)':(
        lambda m: timedelta(hours=m[0],minutes=m[1]) ),
    u'(\d+):(\d+):(\d+)':(
        lambda m: timedelta(hours=m[0],minutes=m[1],seconds=m[2]) ),
    u'(\d+)d(\d+)h':(
        lambda m: timedelta(days=m[0],hours=m[1])),
    u'(\d+)d(\d+):(\d+)':(
        lambda m: timedelta(days=m[0],hours=m[1],minutes=m[2])),
    u'(\d+)d(\d+):(\d+):(\d+)':(
        lambda m: timedelta(days=m[0],hours=m[1],minutes=m[2],
                            seconds=m[3]))
    }

def to_timedelta(s):
    if isinstance(s,timedelta): return s
    if isinstance(s,int): return timedelta(seconds=s)
    if isinstance(s,float): return timedelta(seconds=round(s))
    if not isinstance(s,str):
        raise TypeError('Argument to to_timedelta must be a str not a %s'%(
            type(s).__name__,))
    mult=1
    if s[0]=='-':
        s=s[1:]
        mult=-1
    elif s[0]=='+':
        s=s[1:]
    for regex,fun in DT_REGEX.items():
        m=re.match(regex,s)
        if m:
            ints=[ int(s,10) for s in m.groups() ]
            return mult*fun(ints)
    raise ValueError(s+': invalid timedelta specification (12:34, '
                     '12:34:56, 9d12h, 9d12:34, 9d12:34:56)')

ZERO_DT=timedelta(0)
def str_timedelta(dt):
    sign='+'
    if dt<ZERO_DT:
        dt=-dt
        sign='-'
    d=int(dt.total_seconds()/(3600*24))
    h=int((dt.total_seconds()/3600)%24)
    m=int((dt.total_seconds()/60)%60)
    s=int(dt.total_seconds()%60)
    if d:
        return f'{sign}{d}d{h:02d}:{m:02d}:{s:02d}'
    else:
        return f'{sign}{h:02d}:{m:02d}:{s:02d}'

########################################################################

def memory_in_bytes(s):
    """!Converts 1kb, 3G, 9m, etc. to a number of bytes.  Understands
    k, M, G, P, E (caseless) with optional "b" suffix.  Uses powers of
    1024 for scaling (kibibytes, mibibytes, etc.)"""
    scale = { 'k':1, 'K':1, 'm':2, 'M':2, 'g':3, 'G':3,
              'p':4, 'P':4, 'e':5, 'E':5 }
    if s[-1]=='b': s=s[:-1]
    multiplier=1
    if s[-1] in scale:
        multiplier=1024**scale[s[-1]]
        s=s[:-1]
    return float(s)*multiplier

def to_printf_octal(match):
    """!Intended to be sent to re.sub to replace a single byte match with
    a printf-style octal representation of that byte"""
    i=int.from_bytes(match[1],'big',signed=False)
    return b'\\%03o'%i

def str_to_posix_sh(s,encoding='ascii'):
    """!Convert a string to a POSIX sh represesntation of that string.
    Will produce undefined results if the string is not a valid ASCII
    string.    """

    # Convert from unicode to ASCII:
    if not isinstance(s,bytes):
        if not isinstance(s,str):
            raise TypeError('str_to_posix_sh: argument must be a str '
                            f'or bytes, not a {type(s).__name__}')
        s=bytes(s,'ascii')

    # For strins with no special characterrs, return unmodified
    if re.match(br'(?ms)[a-zA-Z0-9_+:/.,-]+$',s):
        return s

    # For characters that have a special meaning in sh "" strings,
    # prepend a backslash (\):
    s=re.sub(br'(?ms)(["\\])',br'\\\1',s)

    if re.search(br'(?ms)[^ -~]',s):
        # String contains special characters.  Use printf.
        s=re.sub(b'(?ms)([^ -~])',to_printf_octal,s)
        return b'"$( printf \'' + s + b'\' )"'

    return b'"'+s+b'"'

def typecheck(name,obj,cls,tname=None,print_contents=False):
    if not isinstance(obj,cls):
        if tname is None: tname=cls.__name__
        if print_contents:
            msg=f'{name!s} must be type {tname} not {type(obj).__name__!s}' \
                 f' {repr(obj)[:80]}'
        else:
            msg=f'{name!s} must be type {tname} not {type(obj).__name__!s}'
        raise TypeError(msg)

########################################################################

ZERO_DT=timedelta()
class Clock(object):
    def __init__(self,start,step,end=None,now=None):
        typecheck('start',start,datetime.datetime)
        typecheck('step',step,datetime.timedelta)
        if end is not None:
            typecheck('end',end,datetime.datetime)
        self.start=copy(start)
        self.end=end
        self.step=step
        self.__now=start
        if self.step<=ZERO_DT:
            raise ValueError(f'Time step must be positive and non-zero: {self.step}')
        if self.end is not None and self.end<self.start:
            raise ValueError(f'End time must be at or after start time: {self.end}<{self.start}.')
        self.now=now

    def __repr__(self):
        return f'Clock(start={self.start!r},step={self.step!r},'\
               f'end={self.end!r},now={self.now!r})'

    def for_alarm(self,alarm):
        typecheck('alarm',alarm,Clock)
        if alarm.step<self.step or alarm.step%self.step:
            raise ValueError(f"In for_alarm, the alarm's step must be a multiple of the clock's step (clock: {self.step}, alarm: {alarm.step}).")
        if (alarm.start-self.start)%self.step:
            raise ValueError(f"In for_alarm, the alarm start must reside on a clock step (clock: {self}, alarm: {alarm}).")
        start=alarm.start + alarm.step * math.ceil(
            (self.start-alarm.start)/alarm.step)

        if self.end is None:
            # Clock is unbounded, so use the alarm's bound
            end=copy(alarm.end)
        elif alarm.end is None:
            # Clock is bounded, and alarm is unbounded, so use clock's end
            end=copy(self.end)
        else:
            # Both clock and alarm are bounded, so use earliest
            end=min(self.end,alarm.end)

        # If the resulting alarm is bounded, make sur its end lies on
        # an alarm step:
        if end is not None:
            end=alarm.start + alarm.step * math.floor(
                max(ZERO_DT,end-alarm.start)/alarm.step)

        # Start is the first alarm step at or after clock start:
        start=alarm.start + alarm.step * math.ceil(
            max(ZERO_DT,self.start-alarm.start)/alarm.step)

        return Clock(start,alarm.step,end) # No "now" in new alarm.

    def __contains__(self,when):
        if isinstance(when,datetime.timedelta):
            return not when%self.step
        elif isinstance(when,Clock):
            # Are the other clock's times a subset of my times?
            if when.start<self.start: return False # starts before me
            if when.step<self.step: return False # ticks more frequently
            if when.step%self.step: return False # ticks don't line up
            if when.end is None and self.end is not None:
                return False # is eternal, but I have an end time
            if self.end is None:
                return True # I am eternal, so the other clock must
                            # stop before or during my time
            if when.end>self.end: return False # other clock stops after me
            return True
        elif isinstance(when,datetime.datetime):
            if self.end and when>self.end: return False
            if when<self.start: return False
            dt=when-self.start
            if not dt: return True
            if dt%self.step: return False # does not lie on a time step
            return True
        raise TypeError(f'{type(self).__name__}.__contains__ only understands Clock, datetime, and timedelta objects.  You passed type f{type(when).__name__}.')

    def __iter__(self):
        time=self.start
        while time<=self.end:
            yield time
            time+=self.step
    def __str__(self):
        ret='Clock'
        if self.now is not None:
            ret=f'{ret}@{self.now:%Ft%T}'
        ret=f'{ret} from {self.start:%Ft%T} until '
        if self.end is not None:
            ret=f'{ret}{self.end:%Ft%T}'
        else:
            ret=f'{ret}eternity ends'
        return f'{ret} by {str_timedelta(self.step)}'
    def setnow(self,time):
        if time is None:
            self.__now=self.start
            return
        typecheck('time',time,datetime.datetime)
        if (time-self.start) % self.step:
            raise ValueError(
                f'{time} must be an integer multiple of {self.step} '
                f'after {self.start}')
        if self.end is not None and time>self.end:
            raise ValueError(
                f'{time} is after clock end time {self.end}')
        if time<self.start:
            raise ValueError(f'{time} is before clock start time {self.start}')
        self.__now=time
    def getnow(self):
        return self.__now
    now=property(getnow,setnow,None,'Current time on this clock.')

    def iternow(self):
        """!Sents the current time (self.now) to the start time, and
        iterates it over each possible time, yielding this object."""
        now=self.start
        while now<=self.end:
            self.now=now
            yield self
            now+=self.step

    def next(self,mul=1):
        return self.__now+self.step*mul

    def prior(self,mul=1):
        return self.__now+self.step*-mul

########################################################################

_SHELL_CLASS_MAP={ 'int':int, 'float':float, 'bool':bool, 'str':str }

def shell_to_python_type(arg):
    split=arg.split('::',1)
    if len(split)>1 and split[0] in CLASS_MAP:
        typename, strval=split
        if typename not in _SHELL_CLASS_MAP:
            raise ValueError(f'{arg}: unknown type {typename}')
        cls=_SHELL_CLASS_MAP[typename]
        return cls(strval)
    else:
        with suppress(ValueError): return int(arg)
        with suppress(ValueError): return float(arg)
        if arg.upper() in [ 'YES', 'TRUE' ]: return True
        if arg.upper() in [ 'NO', 'FALSE' ]: return False
        return arg

########################################################################

class NamedConstant(object):
    def __init__(self,name):
        self.__name=name
    @property
    def name(self): return self.__name
    def __repr__(self): return f'NamedConstant({self.__name!r})'
    def __str__(self): return self.__name
    def __copy__(self): return self
    def __deepcopy__(self): return self
    def __hash__(self): return hash(self.__name)
    def __eq__(self,other):
        return isinstance(other,NamedConstant) and other.__name==self.__name
    def __ne__(self,other):
        return not isinstance(other,NamedConstant) or other.__name!=self.__name
MISSING=NamedConstant('MISSING')
