# $Id: fullrec.py 6147 2012-11-05 18:11:42Z sprater $
#
# Display full records from Forward
#
# More complex HTTP scripts are best created with the TCPProxy.

import string
import random
import os
from urlparse import urljoin

from net.grinder.script.Grinder import grinder
from net.grinder.script import Test
from net.grinder.plugin.http import HTTPRequest

baseURL = os.environ.get('BASE_URL', 'http://search-test.library.wisconsin.edu/')
fullrecBaseURL = urljoin(baseURL, 'catalog/')

# Read in the fullrecs, put them in a hash
file = open("data/recids.txt", 'r')
lines = file.readlines()

file.close()

test1 = Test(1, "Forward SOLR Full Record Display Test")
request1 = test1.wrap(HTTPRequest())

class TestRunner:

    # The __init__ method is called once for each thread.
    # Put any test thread initializations here
    def __init__(self):
	# Do a single request to launch the Forward Ruby app
        randline = random.choice(lines)
        query = randline.rstrip("\n")
        result = request1.GET(fullrecBaseURL + query)

    # The __call__ method is called for each test run performed by
    # a worker thread.
    def __call__(self):
	# Don't report to the cosole until we verify the result
        grinder.statistics.delayReports = 1
        randline = random.choice(lines)
        query = randline.rstrip("\n")
        result = request1.GET(fullrecBaseURL + query)
        if result.statusCode == 200:
	      # Report to the console
	      grinder.statistics.forLastTest.setSuccess(1)
	else:
	      print result.statusCode


    # The __del__ method is called at shutdown once for each thread
    # It is useful for closing resources (e.g. database connections)
    # that were created in __init__.
    #def __del__(self):
