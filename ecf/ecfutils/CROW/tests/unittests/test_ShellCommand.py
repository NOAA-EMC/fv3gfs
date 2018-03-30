#! /usr/bin/env python3

import unittest
from context import crow

from crow.sysenv import ShellCommand

import os, subprocess

class TestShellCommand(unittest.TestCase):

    def test_ShellCommand(self):
        if os.path.exists('file1'): os.unlink('file1')
        if os.path.exists('file2'): os.unlink('file2')

        cmd=ShellCommand([ '/bin/sh','-c', 'cat $FILE1 $FILE2' ]  ,
                   files=[ { 'name':'file1', 'content':'hello '}  , {'name':'file2', 'content':'world\n'} ],
                     env={ 'FILE1':'file1', 'FILE2':'file2'    }  , cwd='.' )

        result=cmd.run(stdout=subprocess.PIPE,encoding='ascii')
        self.assertTrue(result.stdout=='hello world\n')

        if os.path.exists('file1'): os.unlink('file1')
        if os.path.exists('file2'): os.unlink('file2')
