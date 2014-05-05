Load Testing Overview:  The Grinder
-----------------------------------

We currently use "Grinder" (http://grinder.sourceforge.net/) to load test 
the the UW Madison OPAC application.  Grinder is a java application that 
can be used to launch numerous parallel threads that execute Jython scripts.  
All the targeted load test scenarios are defined in the Jython scripts.

Grinder is a client/server application:  the server is a master process 
that gathers data from the clients and creates the graphs;  the clients 
are processes that run the Jython scripts in threads, and report timing 
data to the server.

The Grinder suite is divided into three pieces:

 * The *Workers*, which spawn threads and run the load test scripts
 * The *Agents*, which manage the Worker processes
 * The *Console*, which gathers all the data submitted by the Agents

See [Grinder - Getting Started](http://grinder.sourceforge.net/g3/getting-started.html)
for more information.

Installing Grinder
------------------

Prerequisites:  Jython 2.5.3, Java SE 7+

Grinder should be run on a different physical host from the one where 
the target application be tested is installed.  You may want to install 
grinder on several hosts, to distribute the load of the agent processes 
across different platforms, and avoid creating resource bottlenecks on the 
launch host.

1. Download and install Jython
```bash
    $ wget http://downloads.sourceforge.net/project/jython/jython/2.5.3/jython_installer-2.5.3.jar?use_mirror=iweb
    $ java -jar jython_installer-2.5.3.jar
```
    Install Jython, take note of where you installed it
```bash
    $ export JYTHON_HOME=</path/to/jython>
```

2. Download Grinder onto your launch host
```bash
    $ wget http://downloads.sourceforge.net/project/grinder/The%20Grinder%203/3.11/grinder-3.11.zip?use_mirror=cdnetworks-us-1
    $ unzip grinder-3.11.zip
    $ export GRINDER_HOME=./grinder-3.11
    $ export CLASSPATH=$JYTHON_HOME/jython.jar:$GRINDER_HOME/lib/grinder.jar
```

Setting up the tests
--------------------

Test suites are checked into the LCB git repository.

At the top level there is the subdirectory **scenarios**.  Scenario 
subdirectories of **scenarios** contain different Grinder test 
scripts and properties files for each scenario.  The first scenario, 
"facets", is for testing simple Forward search queries.  The queries are 
selected randomly for each test from a list of 50,000 facets extracted 
from the OPAC Solr index.

Every test scenario consists of, at a minimum, these two files:

* &lt;scenario&gt;.properties  
  The properties file that defines the scope of the test:  number of worker 
  processes, number of threads per worker, number of tests that will be 
  executed sequentially per thread, the test scripts that will be executed, 
  etc.  See `tests/facets/facets.properties` for an annotated sample properties 
  file.

  Edit the *grinder.jvm.arguments* property to set the `-Dpython.home` parameter 
  to $JYTHON_HOME.

  Documentation for the properties can be found at <http://grinder.sourceforge.net/g3/properties.html>

* &lt;scenario&gt;.py  
  The actual test script.  This is a Jython script (Python in the Java Virtual 
  Machine) that actually performs the test.  See `tests/facets/facets.py` for
  a sample script that loads the 50,000 subject terms into a hash, spawns the 
  appropriate number of test threads, has each thread run an initial query to 
  start up the Forward Ruby application, then has each thread submit queries 
  randomly chosen from the subject terms list over and over.  

The **data** directory contains data that can be used to seed the tests:
`data/queries.txt`, for example, contains the subject terms for the facets
tests.

The **loadtests** directory contains the output of the run of a given load test
scenario.  The individual loadtest is a date-timestamped directory, and 
contains the file `notes.txt` and the session logs subdirectories.

The `NOTES.txt` file contains:

 * The date and time the loadtest was made;
 * The target service;
 * The scenario that was run;
 * The number of sessions, and the increment in workers for each session;
 * How long each session lasted,
 * Notes on the purpose of the test

You can find raw output of the tests in logs subdirectory of the loadtest
directory:  the `*-data.log` files contain raw output, suitable for import
into a spreadsheet and manipulation in Excel;  the `*.logX` files
contain test outputs and summary data (similar to what is shown in the 
console).

Running Grinder Manually
------------------------

First start up the console.  This is a GUI application;  it listens on a
port on your workstation or client machine, collects data from the agents, and
displays real-time summary statistics and data.  This application is used to
start, reset, and stop the agents, and to start and stop collection of
statistics.

On your workstation (or other platform, with X application export enabled):

```bash
    $ export CLASSPATH=$JYTHON_HOME/jython.jar:$GRINDER_HOME/lib/grinder.jar
    $ java net.grinder.Console
```

Then start up your agents.  These can be on the same platform as your console,
or on a different platform (in which case, you'll need to configure the
properties file to specify the hostname and port where the console is
listening.)  Run the agents from the scenario directory, and pass the
properties file as an argument:

```bash
    $ cd forward-loadtest/scenarios/facets
    $ export CLASSPATH=$JYTHON_HOME/jython.jar:$GRINDER_HOME/lib/grinder.jar
    $ java net.grinder.Grinder facets.properties
```
    
Once the agents contact the console, the start and reset icons on the console
will be enabled.  You may use the icons to control the tests, or the "Action"
menu:

* **Action->Collect Statistics**:  Start collection of statistics.
  Do this before you start up the workers.
* **Action->Start Processes**:     Start the worker threads.
* **Action->Stop Processes**:      Stop the worker threads.

Launching the Agent via the Loadtest Script
-------------------------------------------

The script `loadtest.sh` in the root directory automates much of the process 
of configuring and running an agent for a load test.  You may choose to start
the console manually, as described above;  if no console is specified, the
agent will launch the workers automatically.

loadtest.sh takes the following parameters:

>          -S, --scenario:      the scenario to run (required)
>          -t, --target-url:    the base target URL (required)
>          -h, --console-host:  the address of the console host
>                               (default is no console)
>          -p, --console-port:  the port the console host listens on
>                               (default is 6372)
>          -w, --workers:       the number of workers
>                               (default set in properties file)
>          -d, --duration:      the length of time (in seconds) the
>                               workers will run (default set in
>                               properties file)
>          -s, --sessions:      the number of times this loadtest should be
>                               run (default is once)
>          -i, --increment-by:  mathematical expression to use to
>                               increment the number of workers for each
>                               session.  +2 will add two workers each
>                               session, *3 will triple the number of
>                               workers each session. (default is +1)
>                               (used in conjunction with -w, --workers)
>          -n, --notes:         Additional notes about the load test

Logs will be written to the directory `loadtests/<YYYYMMDD-HHMM>`:

* **notes.txt**: Summary of the test's configuration
* **loadtest.log**:  Output of the loadtest script
* **sessionXX/**:  Subdirectories containing the data logs written out by 
  Grinder during each session

Interpreting the Output
-----------------------

See <http://grinder.sourceforge.net/g3/getting-started.html#Output> for
an explanation of the output for each test run.
