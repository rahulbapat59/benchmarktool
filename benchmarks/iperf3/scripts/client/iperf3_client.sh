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
	echo "${REV}-W or --window${NORM} --Sets the value for option ${BOLD}List of window sizes to test (e.g. 64K,83K...)${NORM}. Default is ${BOLD}87380${NORM}."
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

if ! options=$(getopt -o s:c:C:w:u:x:y:hv:p:t:P:W:M:T: -l server:,webserver:,username:,client:,prefile:,postfile:,help,verbose_count:,port:,time:,parallel:,window:,set-mss:,type: -- "$@")
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
		-W|--window) WINDOW="${2//\'/}" ; shift;;
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
#TODO: Define ${LOG_LOCATION} and ${logfile}
#mkdir -p ${LOG_LOCATION}


# REQUIRED: nothing
# STORED: nothing
# $1 is time to sleep
perform_sleep () {
    if [[ -z ${VERBOSE} ]]; then
        echo "[$CLIENT] Sleeping for $1s first to allow server to finish launching."
        sleep $1
    fi
}

# REQUIRED: sshs key between client and server
# STORED: nothing
kill_ip3_server () {
    if [[ -z ${VERBOSE} ]]; then
        echo "[$CLIENT] Killing iperf3 processes on server."
        ssh ${HOST_NAME} pkill iperf3
    fi
}

# REQUIRED: nothing
# STORED: $mss_sizes, $window_sizes, $parallelisms, $start_port2
get_test_parameters () {
    IFS=',' read -r -a mss_sizes <<< "${MSS}"
    IFS=',' read -r -a window_sizes <<< "${WINDOW}"
    IFS=',' read -r -a parallelisms <<< "${PARALLEL}"
    start_port2=$((${PORT}+${parallelisms[-1]}))
}

# REQUIRED: ssh keys between client and server
# STORED: $server_ips
get_server_ip_list () {
    server_ips="$(ssh ${HOST_NAME} "netstat -tulpn 2>/dev/null" | grep iperf3 | awk '{print $4}' | awk -F ':' '{print $1}' | sort -u)"
    # Testing purposes
    #server_ips="1.17.1.53
#10.7.56.123"
    
    if [[ -z $server_ips ]]; then
        echo "[$CLIENT] Server is not listening for iperf3, exiting."
        kill_ip3_server
        exit 1
    fi
    echo "[$CLIENT] SERVER IS USING:"
    echo "$server_ips"
}

# REQUIRED: choose_ifaces.sh script
# STORED: $ip, $ip2, $numa, $numa2
set_my_ip_and_numa () {
    current_script_dir="$(cd "$(dirname "$0")" ; pwd -P)"
    ./choose_ifaces.sh ${TYPE} $current_script_dir ${CLIENT} $server_ips
    ip="$(cat my_info | grep "ip=" | awk -F '=' '{print $2}')"
    ip2="$(cat my_info | grep "ip2=" | awk -F '=' '{print $2}')"
    numa="$(cat my_info | grep "numa=" | awk -F '=' '{print $2}')"
    numa2="$(cat my_info | grep "numa2=" | awk -F '=' '{print $2}')"
    [[ -z $numa ]] && numacmd="" || numacmd="numactl -N $numa"
    [[ -z $numa2 ]] && numacmd2="" || numacmd2="numactl -N $numa2"
    rm my_info 2>/dev/null
    echo
}

# REQUIRED: $ip, $ip2 (set_my_ip_and_numa), 
#           $server_ips (get_server_ip_list)
# STORED: $server_ip, $server_ip2
set_server_ips () {
    ip_type="$(echo $ip | grep -oP "^[0-9]+.[0-9]+.")"
    ip2_type="$(echo $ip2 | grep -oP "^[0-9]+.[0-9]+.")"
    while read -r line; do
        server_ip_type="$(echo "$line" | grep -oP "^[0-9]+.[0-9]+.")"
        if [[ ( "$ip_type" == "$server_ip_type" && -z $server_ip ) ]]; then
            server_ip=$line
        elif [[ ( "$ip2_type" == "$server_ip_type" && -z $server_ip2 ) ]]; then
            server_ip2=$line
        elif [[ ( ! -z $server_ip && ! -z $server_ip2 ) ]]; then
            break
        fi
    done < <(echo "$server_ips")
    # If nothing matched or the second ip didn't match, exit
    if [[ ( -z $server_ip && -z $server_ip2 ) || ( ! -z $ip2 && -z $server_ip2 ) ]]; then
        echo "[$CLIENT] Client/server IPs are incompatible, exiting."
        kill_ip3_server
        exit 1
    fi
    echo "[$CLIENT] $ip will connect to $server_ip."
    [[ ! -z $ip2 ]] && echo "[$CLIENT] $ip2 will connect to $server_ip2."
}

# REQUIRED: Everything from all other functions
# STORED: nothing
# $1 is either "server" or "client"
call_iperf3 () {
    dir=$server_dir
    iperf3="$numacmd iperf3 -c $server_ip -B $ip -t ${TIME}"
    iperf3_2="$numacmd iperf3 -c $server_ip2 -B $ip2 -t ${TIME}"
    if [[ "$1" == "client" ]]; then
        dir=$client_dir
        iperf3="$iperf3 -R"
        iperf3_2="$iperf3_2 -R"
    fi
    for m in "${mss_sizes[@]}"
    do
        for w in "${window_sizes[@]}"
        do
            for p in "${parallelisms[@]}"
            do
                timestamp="$(date +"%I:%M %p")"
                echo "[$CLIENT] ===== MSS=$m, Window=$w, Parallelism=$p ($timestamp) ====="
                curr_port=${PORT}
                curr_port2=$start_port2
                for i in $(seq 1 $p)
                do
                    datafile="$dir/$m-$w-$p-part$i-1.txt"
                    cmd="$iperf3 -p $curr_port -M $m -w $w | tee -a $datafile"
                    [[ "$i" -lt "$p" ]] || [[ ! -z $ip2 ]] && cmd="${cmd} &"
                    echo $cmd >> "client-cmdline.txt"
                    #echo "[$CLIENT] $cmd"
                    [[ -z ${VERBOSE} ]] && eval $cmd
                    curr_port=$((curr_port+1))
                done
                if [[ ! -z $ip2 ]]; then
                    for i in $(seq 1 $p)
                    do
                        datafile="$dir/$m-$w-$p-part$i-2.txt"
                        cmd="$iperf3_2 -p $curr_port2 -M $m -w $w | tee -a $datafile"
                        [[ "$i" -lt "$p" ]] && cmd="${cmd} &"
                        echo $cmd >> "client-cmdline.txt"
                        #echo "[$CLIENT] $cmd"
                        [[ -z ${VERBOSE} ]] && eval $cmd
                        curr_port2=$((curr_port2+1))
                    done
                fi
            done
            [[ -z ${VERBOSE} ]] && sleep 5
        done
    done
}

# The client is run below
timestamp="$(date +"%I:%M %p")"
echo "[$CLIENT] ===== STARTING IPERF3 CLIENT ($timestamp) ====="
perform_sleep 3
get_test_parameters
get_server_ip_list
set_my_ip_and_numa
set_server_ips
server_dir="results/${HOST_NAME}-as-server"
client_dir="results/${HOST_NAME}-as-client"
mkdir -p $server_dir
mkdir -p $client_dir

timestamp="$(date +"%I:%M %p")"
echo "[$CLIENT] ***** BEGINNING IPERF3 WITH ${HOST_NAME} AS SERVER ($timestamp) *****" 
call_iperf3 "server"
echo

timestamp="$(date +"%I:%M %p")"
echo "[$CLIENT] ***** BEGINNING IPERF3 WITH ${HOST_NAME} AS CLIENT ($timestamp) *****"
call_iperf3 "client"
echo

timestamp="$(date +"%I:%M %p")"
echo "[$CLIENT] ***** IPERF3 TESTS HAVE COMPLETED ($timestamp) *****"
kill_ip3_server

echo "[$CLIENT] ***** GENERATING RESULTS CSVs *****"
./make_csv.sh $server_dir $client_dir ${MSS} ${WINDOW} ${PARALLEL}
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

#cp *.csv ../
#CLEAN_UP
#COPY_RESULTS ${WEBSERVER} ${USER_NAME}
