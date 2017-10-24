#!/usr/bin/env bash

ulimit -n 10000

set +x
SCRIPT=`basename ${BASH_SOURCE[0]}`
USER_NAME=`whoami`

{VARS_PYTHON_REPLACE}

function HELP() {
    NORM=`tput sgr0`
    BOLD=`tput bold`
    REV=`tput smso`
    echo -e \\n"Help documentation for ${BOLD}${SCRIPT}.${NORM}"\\n
    echo -e "${REV}Basic usage:${NORM} ${BOLD}$SCRIPT file.ext${NORM}"\\n
    echo "Command line switches are optional. The following switches are recognized."
{VARS_PYTHON_HELP}
    echo -e "${REV}-h${NORM}  --Displays this help message. No further functions are performed."\\n
    echo -e "Example: ${BOLD}$SCRIPT -h${NORM}"\\n
    exit 1
}

function COPY_RESULTS() {
    ssh -l ${2} ${1} "mkdir -p /opt/logs/${TEST_TYPE}/${finalname}/${finalname1}"
    rsync -r ${date_folder}/* ${2}@${1}:/opt/logs/${TEST_TYPE}/${finalname}/${finalname1}
    ssh -l ${2} ${1} "cd /opt/logs/ && ./add_this_result.py /opt/logs/${TEST_TYPE}/${finalname}/${finalname1}/summary_sorted.html /opt/logs/${TEST_TYPE}/${finalname}/${finalname1}/"
    echo "Test Ended"
    echo "LOOK FOR THE RESULTS AT THE RESULTS at http://${1}/${TEST_TYPE}/${finalname}/${finalname1}"
    exit 1
}

function START_POWER_MONITOR(){
            touch $PWD/power_monitor.log
            for pid in `pidof mpstat`
            do
                echo ${pid}>/dev/null 2>&1
            done
	        echo $1
            cmd="python3 get_power.py ${pid} ${PWD}/power_monitor.log ${1}"
            if [ "$VERBOSE" == 1 ]
            then
                echo "`date -u` :: ${cmd}"
            fi
            echo "`date -u` :: ${cmd}" >> cmdline.txt
            eval ${cmd} &
}


function START_SYS_MONITOR(){
            touch $PWD/${LOG_LOCATION}/monitor.log
            mpstat -P ALL 5 | tr -s " " | sed 's/ /,/g' | grep -v '^$' | \
		 grep -v -e '^[A-Z][a-z].*' >> stat.csv &

	    for pid in `pidof mpstat`
            do
                echo ${pid}>/dev/null 2>&1
            done
            cmd="python monitor.py ${date_folder} $pid ${PWD}/${LOG_LOCATION}/monitor.log \
                benchlog_fn.log ${PWD}/${LOG_LOCATION}/monitor.html ${1}"
            if [ "$VERBOSE" == 1 ]
            then
                echo "`date -u` :: ${cmd}"
            fi
            echo "`date -u` :: ${cmd}" >> cmdline.txt
            eval ${cmd} &
}

function ENVIRONMENT_VERSIONS(){
../common/environment.sh
}

function KILL_MPSTAT(){
    if [ "$VERBOSE" == 1 ]
    then
        cmd="sudo killall mpstat"
        echo "`date -u` :: ${cmd}"
    else
        cmd="sudo killall mpstat>/dev/null 2>&1"
    fi
    eval ${cmd}
}

function CLEAN_UP(){
    cd ..
    find . -name *.py -type f -delete
    find . -name *.sh -type f -delete
    find . -name hosts.txt -type f -delete
    find . -name chart-template.html -type f -delete
    find . -name benchlog_fn.log -type f -delete
    cd client0
}

NUMARGS=$#
if [ $NUMARGS -eq 0 ]; then
  HELP
fi

if ! options=$(getopt -o {GETOPS_PYTHON_SHORTTIP_REPLACE} -l {GETOPS_PYTHON_LONGTIP_REPLACE} -- "$@")
then
    exit 1
fi

set -- $options
while [ $# -gt 0 ]
do
    case $1 in
        -s|--server) SYS_NAME="${2//\'/}" HOST_NAME="${2//\'/}" ;shift;;
        -w|--webserver) WEBSERVER="${2//\'/}" ;shift;;
        -u|--username) USER_NAME="${2//\'/}" ;shift;;
        -c|--client) CLIENT="${2//\'/}" ;shift;;
        -C|--Comment) shift;;
        -h|--help) HELP;;
        -v|--verbose_count) VERBOSE=1;shift;;
        -x|--prefile) shift;;
        -y|--postfile) shift;;
{CASE_STATEMENT_PYTHON_REPLACE}
        --) break;;
        -*) ;;
        *) break;;
    esac
    shift
done


date_folder=$(dirname $PWD)
comment_folder=$(dirname ${date_folder})
finalname=$(basename parentdir="$(dirname "$date_folder")")
finalname1=$(basename parentdir="$(dirname "$PWD")")

sudo chmod -R 760 $PWD
touch ${TEST_TYPE}.type

logdate=$(date +%F)

#TODO: Define ${LOG_LOCATION} and ${logfile}
mkdir -p ${LOG_LOCATION}

#TODO:FIRETESTS

touch $PWD/${LOG_LOCATION}/monitor.log
touch $PWD/${LOG_LOCATION}/power_monitor.log

START_SYS_MONITOR ${SYS_NAME}
START_POWER_MONITOR ${SYS_NAME}

echo -n "Power:" >> ${LOG_LOCATION}/${logfile}

KILL_MPSTAT
sleep 10
cat powerstats.csv >> ${LOG_LOCATION}/${logfile}

cp powerstats.csv $PWD/${LOG_LOCATION}
cp power_monitor.log $PWD/${LOG_LOCATION}

echo "Collecting Results"
scp -r ${USER_NAME}@${HOST_NAME}:/opt/benchmarks/${TEST_TYPE}/${finalname}/${finalname1}/SERVER_STATS ../

cp *.csv ../
CLEAN_UP
COPY_RESULTS ${WEBSERVER} ${USER_NAME}
