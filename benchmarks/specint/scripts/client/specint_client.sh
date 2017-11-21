#!/usr/bin/env bash

ulimit -n 10000

set +x
SCRIPT=`basename ${BASH_SOURCE[0]}`
USER_NAME=`whoami`

ITERATIONS=1
COPIES=1
CONFIGPATH="/opt/cpu2017/config/gcc7"
TYPE=int
WEBSERVER="x86-ivy-cb1"

function HELP() {
    NORM=`tput sgr0`
    BOLD=`tput bold`
    REV=`tput smso`
    echo -e \\n"Help documentation for ${BOLD}${SCRIPT}.${NORM}"\\n
    echo -e "${REV}Basic usage:${NORM} ${BOLD}$SCRIPT file.ext${NORM}"\\n
    echo "Command line switches are optional. The following switches are recognized."
        echo "${REV}-i or --iterations${NORM} --Sets the value for option ${BOLD}Number of iterations for coremark${NORM}. Default is ${BOLD}100000${NORM}."
        echo "${REV}-c or --copies${NORM} --Sets the value for option ${BOLD}Number of copies for the spec run${NORM}. Default is ${BOLD}1${NORM}."
        echo "${REV}-f or --configpath${NORM} --Sets the value for option ${BOLD}Location of configuration file${NORM}. Default is ${BOLD}/opt/cpu2006${NORM}."
        echo "${REV}-t or --type${NORM} --Sets the value for option ${BOLD}Spec int or Spec fp${NORM}. Default is ${BOLD}int${NORM}."

    echo -e "${REV}-h${NORM}  --Displays this help message. No further functions are performed."\\n
    echo -e "Example: ${BOLD}$SCRIPT -h${NORM}"\\n
    exit 1
}

function COPY_RESULTS() {
    ssh -l ${2} ${1} "mkdir -p /opt/logs/specint/${finalname}/${finalname1}"
    rsync -r ${date_folder}/* ${2}@${1}:/opt/logs/specint/${finalname}/${finalname1}
    ssh -l ${2} ${1} "cd /opt/logs/ && ./add_this_result.py /opt/logs/specint/${finalname}/${finalname1}/summary_sorted.html /opt/logs/specint/${finalname}/${finalname1}/"
    echo "Test Ended"
    echo "LOOK FOR THE RESULTS AT THE RESULTS at http://${1}/specint/${finalname}/${finalname1}"
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

if ! options=$(getopt -o s:c:C:w:u:x:y:hv:i:c:f:t: -l server:,webserver:,username:,client:,prefile:,postfile:,help,verbose_count:,iterations:,copies:,configpath:,type: -- "$@")
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
                -i|--iterations) ITERATIONS="${2//\'/}" ; shift;;
                -c|--copies) COPIES="${2//\'/}" ; shift;;
                -f|--configpath) CONFIGPATH="${2//\'/}" ; shift;;
                -t|--type) TYPE="${2//\'/}" ; shift;;

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
touch specint.type

logdate=$(date +%F)

#TODO: Define ${LOG_LOCATION} and ${logfile}
id=0
mkdir -p run_${id}
PARENT=$PWD
LOG_LOCATION=run_${id}
logfile=run_${id}_${logdate}.log
sudo rm /opt/cpu2017/result/*
sudo rm -rf `find /opt/cpu2017/benchspec -name run`

touch $PWD/${LOG_LOCATION}/monitor.log
touch $PWD/${LOG_LOCATION}/power_monitor.log

START_SYS_MONITOR ${SYS_NAME}
#START_POWER_MONITOR ${SYS_NAME}

#TODO:FIRETESTS
pushd /opt/cpu2017
. shrc
runcpu -I --iterations=1 --noreportable --output_root=${PARENT}/${LOG_LOCATION} -c ${CONFIGPATH} --copies ${COPIES} ${TYPE}rate > ${PARENT}/${LOG_LOCATION}/${logfile} 2>&1
popd

echo -n "Power:" >> ${LOG_LOCATION}/${logfile}

KILL_MPSTAT
sleep 10
#cat powerstats.csv >> ${LOG_LOCATION}/${logfile}

#cp powerstats.csv $PWD/${LOG_LOCATION}
#cp power_monitor.log $PWD/${LOG_LOCATION}

echo "Collecting Results"
scp -r ${USER_NAME}@${HOST_NAME}:/opt/benchmarks/specint/${finalname}/${finalname1}/SERVER_STATS ../

cp *.csv ../
#CLEAN_UP
COPY_RESULTS ${WEBSERVER} ${USER_NAME}

