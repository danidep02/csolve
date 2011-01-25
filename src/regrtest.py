#!/usr/bin/python
# Copyright (c) 2009 The Regents of the University of California. All rights reserved.
#
# Permission is hereby granted, without written agreement and without
# license or royalty fees, to use, copy, modify, and distribute this
# software and its documentation for any purpose, provided that the
# above copyright notice and the following two paragraphs appear in
# all copies of this software.
#
# IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY
# FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
# ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN
# IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
#
# THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS
# ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION
# TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.

import time, subprocess, optparse, sys, socket
sys.path.append("../")
import external.misc.rtest as rtest

solve      = "./lcc -c".split()
null       = open("/dev/null", "w")
now	   = (time.asctime(time.localtime(time.time()))).replace(" ","_")
logfile    = "../testlogs/regrtest_results_%s_%s" % (socket.gethostname (), now)
argcomment = "//! run with "

def logged_sys_call(args, out=None, err=None):
  print "exec: " + " ".join(args)
  return subprocess.call(args, stdout=out, stderr=err)

def solve_quals(file,bare,time,quiet,flags):
  if quiet: out = null
  else: out = None
  if time: time = ["time"]
  else: time = []
  hygiene_flags = [("--liquidcprefix=%s" % (file)), "-o", "/dev/null"]
  return logged_sys_call(time + solve + flags + hygiene_flags + [file], out)

def run_script(file,quiet):
  if quiet: out = null
  else: out = None
  return logged_sys_call(file, out)

def getfileargs(file):
  f = open(file)
  l = f.readline()
  f.close()
  if l.startswith(argcomment):
    return l[len(argcomment):].strip().split(" ")
  else:
    return []

class Config (rtest.TestConfig):
  def __init__ (self, dargs, testdirs, logfile, threadcount):
    rtest.TestConfig.__init__ (self, testdirs, logfile, threadcount)
    if dargs != "":
      self.dargs = dargs.split(" ")
    else:
      self.dargs = list()

  def run_test (self, file):
    if file.endswith(".c"):
      fargs = getfileargs(file)
      return solve_quals(file, True, False, True, fargs + self.dargs)
    elif file.endswith(".sh"):
      return run_script(file, True)

  def is_test (self, file):
    return file.endswith(".sh") or (file.endswith(".c") and not file.endswith(".ssa.c"))

#####################################################################################

#testdirs  = [("../postests", 0)]
#testdirs  = [("../negtests", 1)]
#testdirs  = [("../slowtests", 1)]

#FOR DEFAULT
testdirs  = [("../postests", 0), ("../negtests", [1, 2])]

#FOR --scalar
#testdirs  = [("../footests", 0)]

parser = optparse.OptionParser()
parser.add_option("-t", "--threads", dest="threadcount", default=1, type=int, help="spawn n threads")
parser.add_option("-o", "--opts", dest="opts", default="", type=str, help="additional arguments to liquidc")
parser.disable_interspersed_args()
options, args = parser.parse_args()

runner = rtest.TestRunner (Config (options.opts, testdirs, logfile, options.threadcount))
runner.run ()
