#!/usr/bin/env bash

ulimit -n 10000

set +x
SCRIPT=`basename ${BASH_SOURCE[0]}`
USER_NAME=`whoami`

PORT=5201
TIME=120
PARALLEL=1
WINDOW=87380
MSS=1460
TYPE=1G


function HELP() {
    NORM=`tput sgr0`
    BOLD=`tput bold`
    REV=`tput smso`
    echo -e \\n"Help documentation for ${BOLD}${SCRIPT}.${NORM}"\\n
    echo -e "${REV}Basic usage:${NORM} ${BOLD}$SCRIPT file.ext${NORM}"\\n
    echo "Command line switches are optional. The following switches are recognized."
	echo "${REV}-p or --port${NORM} --Sets the value for option ${BOLD}The port to use for running iperf3. For multi-parallel tests, ports will be assigned starting with this specified value${NORM}. Default is ${BOLD}5201${NORM}."
	echo "${REV}-t or --time${NORM} --Sets the value for option ${BOLD}Time in seconds to transmit for${NORM}. Default is ${BOLD}120${NORM}."
	echo "${REV}-P or --parallel${NORM} --Sets the value for option ${BOLD}List of parallelisms to test (e.g. 1,2,4,8...)${NORM}. Default is ${BOLD}1${NORM}."
	echo "${REV}-w or --window${NORM} --Sets the value for option ${BOLD}List of window sizes to test (e.g. 64K,83K...)${NORM}. Default is ${BOLD}87380${NORM}."
	echo "${REV}-M or --set-mss${NORM} --Sets the value for option ${BOLD}List of MSS sizes to test (e.g. 128, 256, 512...)${NORM}. Default is ${BOLD}1460${NORM}."
	echo "${REV}-T or --type${NORM} --Sets the value for option ${BOLD}Specify 1G, 10G, 25G, 50G, or 100G test. Assumes a machine has the specified interfaces present${NORM}. Default is ${BOLD}1G${NORM}."

    echo -e "${REV}-h${NORM}  --Displays this help message. No further functions are performed."\\n
    echo -e "Example: ${BOLD}$SCRIPT -h${NORM}"\\n
    exit 1
}

function COPY_RESULTS() {
    ssh -l ${2} ${1} "mkdir -p /opt/logs/iperf3/${finalname}/${finalname1}"
    rsync -r ${date_folder}/* ${2}@${1}:/opt/logs/iperf3/${finalname}/${finalname1}
    ssh -l ${2} ${1} "cd /opt/logs/ && ./add_this_result.py /opt/logs/iperf3/${finalname}/${finalname1}/summary_sorted.html /opt/logs/iperf3/${finalname}/${finalname1}/"
    echo "Test Ended"
    echo "LOOK FOR THE RESULTS AT THE RESULTS at http://${1}/iperf3/${finalname}/${finalname1}"
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

if ! options=$(getopt -o s:c:C:w:u:x:y:hv:p:t:P:w:M:T: -l server:,webserver:,username:,client:,prefile:,postfile:,help,verbose_count:,port:,time:,parallel:,window:,set-mss:,type: -- "$@")
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
		-p|--port) PORT="${2//\'/}" ; shift;;
		-t|--time) TIME="${2//\'/}" ; shift;;
		-P|--parallel) PARALLEL="${2//\'/}" ; shift;;
		-w|--window) WINDOW="${2//\'/}" ; shift;;
		-M|--set-mss) MSS="${2//\'/}" ; shift;;
		-T|--type) TYPE="${2//\'/}" ; shift;;

        --) break;;
        -*) ;;
        *) break;;
    esac
    shift
done


#date_folder=$(dirname $PWD)
#comment_folder=$(dirname ${date_folder})
#finalname=$(basename parentdir="$(dirname "$date_folder")")
#finalname1=$(basename parentdir="$(dirname "$PWD")")
#
#sudo chmod -R 760 $PWD
#touch iperf3.type
#
#logdate=$(date +%F)
#
##TODO: Define ${LOG_LOCATION} and ${logfile}
#mkdir -p ${LOG_LOCATION}
#
echo "===== STARTING IPERF3 SERVER ====="
echo "PORT=${PORT}, TYPE=${TYPE}, PARALLEL=${PARALLEL}"
echo

# Ensure there are no persistent servers running
pkill iperf3 

# Determine what interfaces + numa to use
current_script_dir="$(cd "$(dirname "$0")" ; pwd -P)"
./choose_ifaces.sh ${TYPE} $current_script_dir
ip="$(cat my_info | grep "ip=" | awk -F '=' '{print $2}')"
ip2="$(cat my_info | grep "ip2=" | awk -F '=' '{print $2}')"
numa="$(cat my_info | grep "numa=" | awk -F '=' '{print $2}')"
numa2="$(cat my_info | grep "numa2=" | awk -F '=' '{print $2}')"
rm my_info 2>/dev/null

# Start servers
[[ -z $numa ]] && numacmd="" || numacmd="numactl -N $numa"
num_streams=$(echo ${PARALLEL##*,})
current_port=${PORT}
for i in $(seq 1 $num_streams); do
    cmd="$numacmd iperf3 -s -B $ip -p $current_port &"
    echo $cmd
    [[ "${VERBOSE}" -eq 0 ]] && eval $cmd
    current_port=$(($current_port+1))
done
if [[ ! -z $ip2 ]]; then
    [[ -z $numa2 ]] && numacmd="" || numacmd="numactl -N $numa2"
    current_port2=$((${PORT}+$num_streams))
    for i in $(seq 1 $num_streams); do
        cmd="$numacmd iperf3 -s -B $ip2 -p $current_port2 &"
        echo $cmd
        [[ "${VERBOSE}" -eq 0 ]] && eval $cmd
        current_port2=$(($current_port2+1)) 
    done
fi
echo "===== IPERF3 SERVER STARTED ====="
#
#touch $PWD/${LOG_LOCATION}/monitor.log
#touch $PWD/${LOG_LOCATION}/power_monitor.log
#
#START_SYS_MONITOR ${SYS_NAME}
#START_POWER_MONITOR ${SYS_NAME}
#
#echo -n "Power:" >> ${LOG_LOCATION}/${logfile}
#
#KILL_MPSTAT
#sleep 10
#cat powerstats.csv >> ${LOG_LOCATION}/${logfile}
#
#cp powerstats.csv $PWD/${LOG_LOCATION}
#cp power_monitor.log $PWD/${LOG_LOCATION}
#
#echo "Collecting Results"
#scp -r ${USER_NAME}@${HOST_NAME}:/opt/benchmarks/iperf3/${finalname}/${finalname1}/SERVER_STATS ../
#
#cp *.csv ../
#CLEAN_UP
#COPY_RESULTS ${WEBSERVER} ${USER_NAME}
