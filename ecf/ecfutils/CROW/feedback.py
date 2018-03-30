#! /usr/bin/env python3.6

from collections import defaultdict
from io import StringIO
import re
import random
import sys
import logging

logger=logging.getLogger('feedback')

class Feedback(object):
    def __init__(self):
        self.__terminals=defaultdict(list)
    def read_rules(self,text,filename,lineno):
        iline=lineno-1
        terminal=None
        for line in text.splitlines():
            iline+=1
            if not line: continue
            m=re.match('''(?x)
                ^        (?P<white>    \s*  )     $
              | ^ \s*    (?P<comment>  \#   )
              | ^ -- \s+ (?P<terminal> .*?  ) \s* $
              | ^ \s*    (?P<rule>     .*?  ) \s* $        ''',line)
            if not m:
                logger.error(f'{filename}:{iline}: syntax error: {line}')
            elif m.group('terminal'):
                terminal=m.group('terminal')
                logger.debug(f'{filename}:{iline}: define {terminal}')
            elif m.group('rule'):
                if not terminal:
                    logger.error(f'{filename}:{iline}: rule without a terminal')
                else:
                    rule=m.group('rule')
                    logger.debug(f'{filename}:{iline}: {terminal} => {rule}')
                    self.__terminals[terminal].append(rule)
            elif m.group('white') or m.group('comment'):
                pass
            else:
                logger.debug(f'{filename}:{iline}: ignore line: {line}')

    def expand_terminal(self,terminal,args,fd):
        if terminal not in self.__terminals:
            logger.warning(f'{terminal}: no such terminal')
            return ''
        rules=self.__terminals[terminal]
        if not rules: return ''
        rule=random.choice(rules)
        return self.expand_text(rule,args,fd)

    def expand_text(self,text,args,fd):
        for match in re.finditer('''(?x)
                \( (?P<terminal> [^()\[\]] + ) \)
              | % (?P<pct> [^0-9] )
              | % (?P<arg> \d+ )
              | (?P<text> [^()\[\]%] + )
              | \[ (?P<box> [^\]]+ ) \]
              | (?P<error> . ) ''',text):
            if not match: return
            if match.group('terminal'):
                self.expand_terminal(match.group('terminal'),args,fd)
            if match.group('box') and random.choice([True,False]):
                self.expand_text(match.group('box'),args,fd)
            if match.group('text'):
                fd.write(match.group('text'))
            if match.group('pct'):
                p=match.group('pct')
                PCT={ '%':'%', '<':'(', '>':')', 'n':'\n', 't':'\t', '_':' ' }
                if p in PCT:
                    fd.write(PCT[p])
                else:
                    logger.warning(f"%{p}: don't know what to do with this")
            if match.group('arg'):
                arg=match.group('arg')
                try:
                    fd.write(args[int(arg,10)])
                except(LookupError,ValueError) as s:
                    logger.warning(f'%{arg}: {str(s)}')
def main():
    logging.basicConfig(stream=sys.stderr,level=logging.INFO)
    if len(sys.argv)<2:
        logger.info('''
  Generates human-friendly messages about workflow status.
Syntax:
   feedback terminal [arg1 [arg2 [...] ]] < input
Example:

./feedback.py 'FAILED INTRO AND SIG' FV3 "Forecast-Only Summer 2016 Baseline" \
      STATUS_REPORT_GOES_HERE Surge VERBOSE_STATUS_REPORT_GOES_HERE \
   < parm/hippie.i

./feedback.py 'INTRO AND SIG' FV3 "Forecast-Only Summer 2016 Baseline" \
      STATUS_REPORT_GOES_HERE Surge VERBOSE_STATUS_REPORT_GOES_HERE \
   < parm/hippie.i
''')
        exit(0)
    fb=Feedback()
    fb.read_rules(sys.stdin.read(),'stdin',1)
    fb.expand_terminal(sys.argv[1],sys.argv[2:],sys.stdout)

if __name__ == '__main__': main()
