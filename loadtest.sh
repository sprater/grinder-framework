#!/bin/bash

#----------------------------------------------------------------------#
#                                                                      #
#  loadtest.sh                                                         #
#                                                                      #
#  Script to configure and launch Grinder loadtests.                   #
#                                                                      #
#  Usage:  ./loadtest.sh                                               #
#            -s, --scenario:      the scenario to run (required)       #
#            -t, --target-url:    the base target URL (required)       #
#            -h, --console-host:  the address of the console host      #
#                                 (default is no console)              #
#            -p, --console-port:  the port the console host listens on #
#                                 (default is 6372)                    #
#            -w, --workers:       the number of workers                #
#                                 (default set in properties file)     #
#            -d, --duration:      the length of time (in seconds) the  #
#                                 workers will run (default set in     #
#                                 properties file)                     #
#            -s, --sessions:      the number of times this test should #
#                                 be run (default is once)             #
#            -i, --increment-by:  mathematical expression to use to    #
#                                 increment the number of workers for  #
#                                 each session.  "+2" will add two     #
#                                 workers each session, "*3" will      #
#                                 triple the number of workers each    #
#                                 session. (default is +1)             #
#                                 (used in conjunction with --workers) #
#            -n, --notes:         Additional notes about the load test #
#            -k, --keep-results   Save the results of the load test    #
#                                 (default is to discard results)      #
#                                                                      #
#  Scott Prater                                                        #
#  Shared Development Group                                            #
#  UW Madison General Library System                                   #
#  September 2012                                                      #
#----------------------------------------------------------------------#

#----------------------------------------------------------------------#
# Functions                                                            #
#----------------------------------------------------------------------#

usage () {
    echo "Usage:  $0" 1>&2
    echo "          -S, --scenario:      the scenario to run (required)" 1>&2
    echo "          -t, --target-url:    the base target URL (required)" 1>&2
    echo "          -h, --console-host:  the address of the console host" 1>&2
    echo "                               (default is no console)" 1>&2
    echo "          -p, --console-port:  the port the console host listens on" 1>&2
    echo "                               (default is 6372)" 1>&2
    echo "          -w, --workers:       the number of workers" 1>&2
    echo "                               (default set in properties file)" 1>&2
    echo "          -d, --duration:      the length of time (in seconds) the" 1>&2
    echo "                               workers will run (default set in " 1>&2
    echo "                               properties file)" 1>&2
    echo "          -s, --sessions:      the number of times this test should be" 1>&2
    echo "                               run (default is once)" 1>&2
    echo "          -i, --increment-by:  mathematical expression to use to" 1>&2
    echo "                               increment the number of workers for each" 1>&2
    echo "                               session.  "+2" will add two workers each" 1>&2
    echo "                               session, "*3" will triple the number of" 1>&2
    echo "                               workers each session. (default is +1)" 1>&2
    echo "                               (used in conjunction with -w, --workers)" 1>&2
    echo "          -n, --notes:         Additional notes about the load test" 1>&2
    echo "          -k, --keep-results   Save the results of the load test" 1>&2
    echo "                               (default is to discard results)" 1>&2

    exit 1
}

teelog () {
	echo "$1" | tee -a "$2"
}

#----------------------------------------------------------------------#
# Configuration                                                        #
#----------------------------------------------------------------------#

# Get the right environment set up
source ~/.bash_profile

# Java home
if [ "X$JAVA_HOME" == "X" ]
then
    JAVA_HOME=$OPSTOOLS_HOME/jdk/jdk-1.7.0_11
    export JAVA_HOME
fi

# Grinder home
if [ "X$GRINDER_HOME" == "X" ]
then
    GRINDER_HOME=$OPSTOOLS_HOME/grinder/grinder-3.11
    export GRINDER_HOME
fi

# Source in the Grinder environment
. $GRINDER_HOME/bin/setGrinderEnv.sh

# Set the Grinder JVM properties
propstring="-Dgrinder.jvm=${JAVA_HOME}/bin/java" 
jvmargs="-Dpython.home=$JYTHON_HOME -Dpython.cachedir=/var/tmp"

# Default number of times to run the test
sessions=1

# Current working directory
currdir=`dirname $0`

# Datestamp directory for logs and output
datedir=`date '+%Y%m%d-%H%M'`

# Default console port
default_port=6372

# Default increment
increment="+1"

# Discard results by default
keep_results="false"

#----------------------------------------------------------------------#
# Main                                                                 #
#----------------------------------------------------------------------#

## Get the options
OPTS=`getopt -s bash -n $0 -o S:t:h:p:w:d:s:i:n:k -l scenario:,target-url:,console-host:,console-port:,workers:,duration:,sessions:,increment-by:,notes:,keep-results -- "$@"`
if [ $? != 0 ]
then
    usage;
fi

eval set -- "$OPTS"

while true
do
    case "$1" in
        -S|--scenario) 
            shift
            scenario="$1"
            ;;
	-t|--target-url) 
            shift
            targeturl="$1"
            ;;
	-h|--console-host) 
            shift
            host="$1"
            ;;
	-p|--console-port) 
            shift
            port="$1"
            ;;
	-w|--workers) 
            shift
            workers="$1"
            ;;
	-d|--duration) 
            shift
	    duration="$1"
	    let msduration=duration*1000
	    propstring="$propstring -Dgrinder.duration=$msduration"
            ;;
	-s|--sessions) 
            shift
            sessions="$1"
            ;;
	-i|--increment-by) 
            shift
            increment="$1"
            ;;
	-n|--notes) 
            shift
            notes="$1"
            ;;
	-k|--keep-results) 
            keep_results="true"
            ;;
	--)
            shift
            break
            ;;
	*) 
            shift
            break
            ;;
    esac
    shift
done

# Check for our required parameters
flag=0
if [ "X$scenario" == "X" ]
then
    echo "Please provide the scenario to run." 1>&2
    flag=1
fi

if [ "X$targeturl" == "X" ]
then
    flag=1
    echo "Please provide the service target base url for the loadtest." 1>&2
else
    BASE_URL="$targeturl"
    export BASE_URL
fi

if [ "$flag" -eq 1 ]
then
    usage
fi

# Check that scenario directory and files exist:
#   scenarios/<scenario>/<scenario>.properties, <scenario>.py
if [ ! -d "$currdir/scenarios/$scenario" ]
then
    echo "Scenario directory scenarios/$scenario does not exist.  Please create it, or choose a different scenario." 1>&2
    exit 1
fi

if [ ! -f "$currdir/scenarios/$scenario/${scenario}.properties" ]
then
    echo "Scenario properties file scenarios/scenario/${scenario}.properties does not exist.  Please create it, or choose a different scenario." 1>&2
    exit 1
else
    grinderproperties="$currdir/scenarios/$scenario/${scenario}.properties"
fi

if [ ! -f "$currdir/scenarios/$scenario/${scenario}.py" ]
then
    echo "Scenario script scenarios/$scenario/${scenario}.py does not exist.  Please create it, or choose a different scenario." 1>&2
    exit 1
else
    propstring="$propstring -Dgrinder.script=${scenario}.py"
fi

# Set up the logs
mkdir -p $currdir/loadtests/$datedir || exit 1
logdir="$currdir/loadtests/$datedir"
logfile="$logdir/loadtest.log"

# Set the console host and port, if any
if [ "X$port" != "X" -a "X$host" == "X" ]
then
    teelog "No console host specified.  Ignoring console port, running without a console." $logfile
    propstring="$propstring -Dgrinder.useConsole=false"
fi

if [ "X$host" != "X" ]
then
    if [ "X$port" == "X" ]
    then
        port=$default_port
    fi

    propstring="$propstring -Dgrinder.useConsole=true -Dgrinder.consoleHost=$host -Dgrinder.consolePort=$port"
else
    propstring="$propstring -Dgrinder.useConsole=false"
fi

# Write out the notes file
cat > $logdir/notes.txt << EOF
Date:                          `date`
Scenario:                      $scenario
Target:                        $targeturl
Number of Sessions:            $sessions
EOF

if [ "X$duration" != "X" ]
then
    echo "Duration (secs) per session:   $duration" >> $logdir/notes.txt
else
    echo "Duration (secs) per session:   [set in properties file]" >> $logdir/notes.txt
fi

if [ "X$workers" != "X" ]
then
    echo "Number of workers:             $workers" >> $logdir/notes.txt
    echo "Workers increased by $increment each session" >> $logdir/notes.txt
else
    echo "Number of workers:             [set in properties file]" >> $logdir/notes.txt
fi

if [ "X$notes" != "X" ]
then
    echo "Notes:" >> $logdir/notes.txt
    echo "$notes" >> $logdir/notes.txt
fi

# Loop through the sessions, run the tests for each session
count=1
basepropstring="$propstring"
while [[ $count -le $sessions ]]
do
    # Set the Grinder output directory
    dirsess=`printf '%02d' $count`
    mkdir -p $logdir/session${dirsess}
    propstring="$basepropstring -Dgrinder.logDirectory=$logdir/session${dirsess}"

    # Set the number of workers for this session
    if [ "X$workers" != "X" ]
    then
         propstring="$propstring -Dgrinder.processes=$workers"
	 let workers=workers$increment || exit 1
    fi 

    # Record the session
    teelog "=========================" $logfile
    teelog "Session $count" $logfile
    teelog "Starting at `date`..." $logfile
    teelog "Running '$JAVA_HOME/bin/java -classpath $CLASSPATH -Dgrinder.jvm.arguments=\"$jvmargs\" $propstring net.grinder.Grinder $grinderproperties'..." $logfile
    $JAVA_HOME/bin/java -classpath $CLASSPATH -Dgrinder.jvm.arguments="$jvmargs" $propstring net.grinder.Grinder $grinderproperties > >(tee -a $logfile) 2> >(tee -a $logfile >&2)
    teelog "Finished at `date`." $logfile

    (( count++ ))
done

grep ERROR $logfile && exit 1

teelog "=========================" $logfile
teelog "Load test ended successfully." $logfile

# If keep_results is true, gzip and commit the results to git
if [ "X${keep_results}" == "Xtrue" ]
then
    echo "Compressing collected data..."
    tar cvfz loadtests/${datedir}.tgz -C loadtests $datedir
    rm -rf $logdir

    echo "Committing the compressed data..."
    git add loadtests/${datedir}.tgz
    git commit -m"forward-loadtest:  add loadtest collected data" loadtests/${datedir}.tgz
    git push origin
fi

echo "Done."

exit
