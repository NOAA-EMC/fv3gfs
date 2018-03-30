import logging
import os
from abc import abstractmethod
from collections import UserList, Mapping, Sequence, OrderedDict
from subprocess import Popen, PIPE, CompletedProcess

__all__=['ShellCommand']

logger=logging.getLogger('crow')

class ShellCommand(object):
    def __init__(self,command,env=False,files=False,cwd=False):
        if isinstance(command,str):
            self.command=[ '/bin/sh', '-c', command ]
        elif isinstance(command,Sequence) and not isinstance(command,bytes):
            self.command=[ str(s) for s in command ]
        else:
            raise TypeError('command must be a string or list, not a '+
                            type(s).__name__)

        self.env=dict(env) if env else None
        self.files=OrderedDict()
        self.cwd=cwd or None

        if not files: return # nothing more to do

        for f in files:
            self.files[f['name']]=f

    @staticmethod
    def from_object(obj):
        if isinstance(obj,str):
            return ShellCommand(obj)
        elif isinstance(obj,ShellCommand):
            return obj
        elif isinstance(obj,Mapping):
            return ShellCommand(**obj)
        elif isinstance(obj,Sequence):
            return ShellCommand(list(obj))
        raise TypeError(f'Cannot convert a {type(obj).__name__} to a '
                        'ShellCommand')
            
    def __str__(self):
        return f'{type(self).__name__}(command={self.command}, ' + \
          f'env={self.env!r}, cwd={self.cwd!r}, files=[ ' + \
          ', '.join([ repr(v) for k,v in self.files.items() ]) + '])'
        
    def run(self,input=None,stdin=None,stdout=None,stderr=None,timeout=None,
            check=False,encoding=None):
        """!Runs this command via subprocess.Pipe.  Returns a
        CompletedProcess.  Arguments have the same meaning as
        subprocess.run.        """
        for name,f in self.files.items():
            mode=f.get('mode','wt')
            logger.info(f'{f["name"]}: write mode {mode}')
            with open(f['name'],mode) as fd:
                fd.write(str(f['content']))

        env=None
        if self.env:
            env=dict(os.environ)
            env.update(self.env)

        logger.info(f'Popen {repr(self.command)}')
        pipe=Popen(args=self.command,stdin=stdin,stdout=stdout,
                   stderr=stderr,encoding=encoding,
                   cwd=self.cwd,env=env)
        (stdout, stderr) = pipe.communicate(input=input,timeout=timeout)
        cp=CompletedProcess(self.command,pipe.returncode,stdout,stderr)
        if check:
            cp.check_returncode()
        return cp
