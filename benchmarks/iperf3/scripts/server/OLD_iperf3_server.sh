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

# Get list of interfaces
iface_list=""
interfaces=$(ip link | grep "^[0-9]:" | awk -F ': ' '{print $2}' | awk -F '@' '{print $1}')
while read -r line; do
    ip="$(ifconfig | grep -A1 -P "$line[:| ]+" | tail -n1 \
        | grep -oP "[0-9]+.[0-9]+.[0-9]+.[0-9]+" | head -n1)"
    if [[ ! -z $ip ]]; then
        speed="$(ethtool $line 2>/dev/null | grep -i "speed:" \
            | awk -F ': ' '{print $2}' | awk -F 'b/s' '{print $1}' \
            | numfmt --from=si --to=si 2>/dev/null --format="%.0f")"
        if [[ ! -z $speed ]]; then
            iface_list="$iface_list$line/$ip/$speed\n"
        fi
    fi
done < <(echo "$interfaces")
ip="" && speed=""
echo "Listing interfaces..."
echo -e $iface_list

# Determine if there are matching interfaces
[[ "${TYPE}" == "50G" ]] && search_speed="25G" || search_speed="${TYPE}"
matching=$(echo -e $iface_list | grep $search_speed)
# No matching speed: use 10.7.56 interface (any speed)
if [[ -z $matching ]]; then
    echo "There are no $search_speed interfaces on this machine."
    first_ip10=$(echo -e "$iface_list" | grep 10.7.56 | head -n 1)
    iface=$(echo "$first_ip10" | awk -F '/' '{print $1}' | awk -F '.' '{print $1}')
    numa="$(cat /sys/class/net/$iface/device/numa_node)"    
    ip=$(echo $first_ip10 | awk -F '/' '{print $2}')
    speed=$(echo $first_ip10 | awk -F '/' '{print $3}')
    echo "Using first 10.7.56 interface ($first_ip10)."
else
    occurrences=$(echo "$matching" | wc -l)
    speed=${TYPE}
fi

# TEST IFACES
#matching="eth3.100/1.17.1.92/25G
#eth3/1.17.1.32/25G
#eth4/1.17.1.41.25G"
#occurrences=$(echo "$matching" | wc -l)

# Determine which interface(s) to use for test
# If there are multiple matches, follow priority
if [[ "$occurrences" -gt 1 ]]; then
    ip17=$(echo "$matching" | grep 1.17)
    ip18=$(echo "$matching" | grep 1.18)
    ip10=$(echo "$matching" | grep 10.7.56)
    # 50G: 1.17+1.18 > 1.17+1.17/1.18+1.18 > 1.17+10.7.56 > 10.7.56+10.7.56
    if [[ "$TYPE" == "50G" ]]; then
        # Case 1: both 1.17 and 1.18 present
        if [[ ! -z $ip17 ]] && [[ ! -z $ip18 ]]; then
            ip=$ip17
            ip2=$ip18
        # Case 2: only 10.7.56 present
        elif [[ -z $ip17 ]] && [[ -z $ip18 ]]; then
            ip=$ip10
            ip2=$(echo "$ip10" | sed 1d)
        # Case 3: two or more of 1.17 or 1.18
        elif [[ $(echo "$ip17" | wc -l) -gt 1 ]] || [[ $(echo "$ip18" | wc -l) -gt 1 ]]; then
            [[ -z $ip17 ]] && has_value="$ip18" || has_value="$ip17"
            ip=$has_value
            ip2=$(echo "$has_value" | sed 1d)
        # Case 4: only one 1.17 or 1.18, and 10.7.56
        else
            [[ -z $ip17 ]] && has_value="$ip18" || has_value="$ip17"
            ip=$has_value
            ip2=$ip10
        fi
        iface=$(echo "$ip" | head -n 1 | awk -F '/' '{print $1}' | awk -F '.' '{print $1}')
        iface2=$(echo "$ip2" | head -n 1 | awk -F '/' '{print $1}' | awk -F '.' '{print $1}')
        numa="$(cat /sys/class/net/$iface/device/numa_node)"
        numa2="$(cat /sys/class/net/$iface2/device/numa_node)"
        ip=$(echo "$ip" | head -n 1 | awk -F '/' '{print $2}')
        ip2=$(echo "$ip2" | head -n 1 | awk -F '/' '{print $2}')
        echo "Using ($ip) and ($ip2)."
    # 1G/10G/25G/100G: 1.17 > 1.18 > 10.7.56 > 10.0.0
    else
        if [[ ! -z $ip17 ]]; then
            ip=$ip17
        elif [[ ! -z $ip18 ]]; then
            ip=$ip_18
        elif [[ ! -z $ip10 ]]; then
            ip=$ip_10
        else
            ip=$matching
        fi
        iface=$(echo "$ip" | head -n 1 | awk -F '/' '{print $1}' | awk -F '.' '{print $1}')
        numa="$(cat /sys/class/net/$iface/device/numa_node)"
        ip=$(echo "$ip" | head -n 1 | awk -F '/' '{print $2}')
        echo "More than one $speed interface found, using ($ip)."
    fi
# If there's only one match, obviously use that one
elif [[ "$occurrences" -eq 1 ]]; then
    [[ "$speed" == "50G" ]] && echo "Only one 25G interface available, switching to 25G test."
    iface=$(echo "$matching" | awk -F '/' '{print $1}' | awk -F '.' '{print $1}')
    numa="$(cat /sys/class/net/$iface/device/numa_node)"
    ip=$(echo "$matching" | awk -F '/' '{print $2}')
    echo "Using ($ip)."
fi

# Start servers
[[ -z $numa ]] && numacmd="" || numacmd="numactl -N $numa"
num_streams=$(echo ${PARALLEL##*,})
current_port=${PORT}
for i in $(seq 1 $num_streams); do
    cmd="$numacmd iperf3 -s -B $ip -p $current_port &"
    [[ "${VERBOSE}" -gt 0 ]] && echo $cmd || eval $cmd
    current_port=$(($current_port+1))
done
if [[ "$speed" == "50G" ]]; then
    [[ -z $numa2 ]] && numacmd="" || numacmd="numactl -N $numa2"
    current_port2=$((${PORT}+$num_streams))
    for i in $(seq 1 $num_streams); do
        cmd="$numacmd iperf3 -s -B $ip2 -p $current_port2 &"
        [[ "${VERBOSE}" -gt 0 ]] && echo $cmd || eval $cmd
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
