# $Id: logreplay.py 6165 2012-11-08 20:15:36Z sprater $
#
# Display full records from Forward
#
# More complex HTTP scripts are best created with the TCPProxy.

import string
import random
import os
from urlparse import urljoin
import re

from net.grinder.script.Grinder import grinder
from net.grinder.script import Test
from net.grinder.plugin.http import HTTPRequest

baseURL = os.environ.get('BASE_URL', 'http://search-test.library.wisconsin.edu/')

format_pat= re.compile(
    r'.*\s"(.+?)"\s'
    )

request_pat= re.compile( r"(\S+)\s(.+?)\sHTTP" )

# Read in the logfile
logfile = grinder.getProperties()["grinder.apachelog"]
try:
    file = open(logfile, 'r')
except IOError, e:
    sys.stderr.write(e)
    sys.exit(1)
else:
    lines = file.readlines()
    file.close()

requests = []
for line in lines:
    match = format_pat.match(line)
    if match:
        req = match.groups()[0]
        match2 = request_pat.match(req)
        if match2:
            requests.append( { 'method': match2.groups()[0], 'uri': match2.groups()[1] } )

test1 = Test(1, "Forward Log Replay Test")
request1 = test1.wrap(HTTPRequest())

class TestRunner:

    count = 0

    # The __init__ method is called once for each thread.
    # Put any test thread initializations here
    def __init__(self):
	# Do a single request to launch the Forward Ruby app
        result = request1.GET(baseURL + "/")

    # The __call__ method is called for each test run performed by
    # a worker thread.
    def __call__(self):
	# Don't report to the console until we verify the result
        grinder.statistics.delayReports = 1
        nextreq = requests[self.count]
	reqmeth = getattr(request1, nextreq['method'])
	result = reqmeth(baseURL + nextreq['uri'][1:])
        if result.statusCode == 200:
	      # Report to the console
	      grinder.statistics.forLastTest.setSuccess(1)
	else:
	      print result.statusCode

        self.count = self.count + 1
        if self.count == len(requests):
            self.count = 0

    # The __del__ method is called at shutdown once for each thread
    # It is useful for closing resources (e.g. database connections)
    # that were created in __init__.
    #def __del__(self):
