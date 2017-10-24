#!/usr/bin/env bash

ulimit -n 10000

set +x
SCRIPT=`basename ${BASH_SOURCE[0]}`
USER_NAME=`whoami`
LOCALIP=localhost
BASEDIR=/usr
DATADIR=/opt/benchmarks/mysql_data
MYSQLDDIR=/usr/sbin
MYSQLDIR=/usr/bin
MAX_TIME=120
TABLE_COUNT_LIST=1
TABLE_ROW_LIST=10000
THREADS_LIST=1
MODE=oltp_read_only
CONFFILE=2
WEBSERVER=127.0.0.1
function HELP() {
    NORM=`tput sgr0`
    BOLD=`tput bold`
    REV=`tput smso`
    echo -e \\n"Help documentation for ${BOLD}${SCRIPT}.${NORM}"\\n
    echo -e "${REV}Basic usage:${NORM} ${BOLD}$SCRIPT file.ext${NORM}"\\n
    echo "Command line switches are optional. The following switches are recognized."
	echo "${REV}-l or --localip${NORM} --Sets the value for option ${BOLD}interface on which the benchmarks will run. Local IP address of server${NORM}. Default is ${BOLD}localhost${NORM}."
	echo "${REV}-b or --basedir${NORM} --Sets the value for option ${BOLD}base directory for mysql server installation${NORM}. Default is ${BOLD}/usr${NORM}."
	echo "${REV}-d or --datadir${NORM} --Sets the value for option ${BOLD}data directory for mysql server installation${NORM}. Default is ${BOLD}/opt/benchmarks/mysql_data${NORM}."
	echo "${REV}-dd or --mysqlddir${NORM} --Sets the value for option ${BOLD}Directory in which mysqld daemon binary is present on server${NORM}. Default is ${BOLD}/usr/sbin${NORM}."
	echo "${REV}-ad or --mysqldir${NORM} --Sets the value for option ${BOLD}Directory in which mysql server binary is present on server${NORM}. Default is ${BOLD}/usr/bin${NORM}."
	echo "${REV}-m or --maxtime${NORM} --Sets the value for option ${BOLD}Time period for which the test should run${NORM}. Default is ${BOLD}120${NORM}."
	echo "${REV}-tc or --tablecount${NORM} --Sets the value for option ${BOLD}A list of table counts for which the test should be run. This is passed as a quoted string${NORM}. Default is ${BOLD}1${NORM}."
	echo "${REV}-tr or --tablerow${NORM} --Sets the value for option ${BOLD}A list of number of rows per table the test should be run. This is passed as a quoted string${NORM}. Default is ${BOLD}10000${NORM}."
	echo "${REV}-tl or --threadlist${NORM} --Sets the value for option ${BOLD}A list of number of different threads for which the test needs to be run. This is passed as a quoted string${NORM}. Default is ${BOLD}1${NORM}."
	echo "${REV}-mo or --mode${NORM} --Sets the value for option ${BOLD}Choose between read-only or read-write${NORM}. Default is ${BOLD}read-only${NORM}."
	echo "${REV}-cf or --conffile${NORM} --Sets the value for option ${BOLD}Choose from the possible conffiles${NORM}. Default is ${BOLD}2${NORM}."

    echo -e "${REV}-h${NORM}  --Displays this help message. No further functions are performed."\\n
    echo -e "Example: ${BOLD}$SCRIPT -h${NORM}"\\n
    exit 1
}

function COPY_RESULTS() {
    ssh -l ${2} ${1} "mkdir -p /opt/logs/sysbench-mysql/${finalname}/${finalname1}"
    rsync -r ${date_folder}/* ${2}@${1}:/opt/logs/sysbench-mysql/${finalname}/${finalname1}
    #ssh -l ${2} ${1} "cd /opt/logs/ && ./add_this_result.py /opt/logs/sysbench-mysql/${finalname}/${finalname1}/summary_sorted.html /opt/logs/sysbench-mysql/${finalname}/${finalname1}/"
    echo "Test Ended"
    echo "LOOK FOR THE RESULTS AT THE RESULTS at http://${1}/sysbench-mysql/${finalname}/${finalname1}"
    exit 1
}

function START_POWER_MONITOR(){
            touch $PWD/power_monitor.log
            for pid in `pidof mpstat`
            do
                echo ${pid}>/dev/null 2>&1
            done
	        echo $1
            cmd="python3 get_power.py ${pid} ${PWD}/${LOG_LOCATION}/power_monitor.log ${1}"
            if [ "$VERBOSE" == 1 ]
            then
                echo "`date -u` :: ${cmd}"
            fi
            echo "`date -u` :: ${cmd}" >> ${LOG_LOCATION}/cmdline.txt
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
./environment.sh
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

if ! options=$(getopt -o s:c:C:w:u:x:y:hv:l:b:d:dd:ad:m:tc:tr:tl:mo:cf: -l server:,webserver:,username:,client:,prefile:,postfile:,help,with_install,verbose_count:,localip:,basedir:,datadir:,mysqlddir:,mysqldir:,maxtime:,tablecount:,tablerow:,threadlist:,mode:,conffile: -- "$@")
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
		-l|--localip) LOCALIP="${2//\'/}" ; shift;;
		-b|--basedir) BASEDIR="${2//\'/}" ; shift;;
		-d|--datadir) DATADIR="${2//\'/}" ; shift;;
		-dd|--mysqlddir) MYSQLDDIR="${2//\'/}" ; shift;;
		-ad|--mysqldir) MYSQLDIR="${2//\'/}" ; shift;;
		-m|--maxtime) MAX_TIME="${2//\'/}" ; shift;;
		-tc|--tablecount) TABLE_COUNT_LIST="${2//\'/}" ; shift;;
		-tr|--tablerow) TABLE_ROW_LIST="${2//\'/}" ; shift;;
		-tl|--threadlist) THREADS_LIST="${2//\'/}" ; shift;;
		-mo|--mode) MODE="${2//\'/}" ; shift;;
		-cf|--conffile) CONFFILE="${2//\'/}" ; shift;;
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
touch sysbench_sql.type

logdate=$(date +%F)

echo "Starting Client"
for TABLE_COUNT in ${TABLE_COUNT_LIST//,/ } ;do
    for TABLE_ROWS in ${TABLE_ROW_LIST//,/ } ;do
        echo "Preparing test"

        cmd="sysbench /usr/local/share/sysbench/${MODE}.lua --tables=${TABLE_COUNT} \
            --table_size=${TABLE_ROWS} --mysql-db=dbtest --threads=24 --time=${MAX_TIME} --mysql-host=${HOST_NAME} \
            --mysql-user='cavium' --mysql-password='some_pass' prepare"

        eval ${cmd} >/dev/null 2>&1
        echo "`date -u` :: ${cmd}" >> cmdline.txt
        for THREADS in ${THREADS_LIST//,/ }; do
            LOG_LOCATION=${TABLE_COUNT}/${TABLE_ROWS}/${THREADS}
            mkdir -p ${LOG_LOCATION}
#            sudo chmod 777 -R .
            mpstat -P ALL 5 | tr -s " " | sed 's/ /,/g' | grep -v '^$' | \
            grep -v -e '^[A-Z][a-z].*' >> ${LOG_LOCATION}/stat.csv &
            sleep 1

            date_folder=$(dirname $PWD)
            comment_folder=$(dirname ${date_folder})
            finalname=$(basename parentdir="$(dirname "$date_folder")")
            finalname1=$(basename parentdir="$(dirname "$PWD")")

            for pid in `pidof mpstat`
            do
                echo ${pid}>/dev/null 2>&1
            done

            touch $PWD/${LOG_LOCATION}/monitor.log
            touch $PWD/${LOG_LOCATION}/power_monitor.log

            START_SYS_MONITOR ${SYS_NAME}
            START_POWER_MONITOR ${SYS_NAME}

            logfile="log-$logdate-oltp-${TABLE_COUNT}TC-${TABLE_ROWS}Rows-${THREADS}Threads.log"

            echo "Running tests"
            echo "############## Running Thread: " ${THREADS} " Tables " ${TABLE_COUNT}" Rows " ${TABLE_ROWS} "##############"
            echo "Benchmark options:" > ${LOG_LOCATION}/${logfile}
            echo "sysbench tables count:${TABLE_COUNT}" >> ${LOG_LOCATION}/${logfile}
            echo "sysbench table size:${TABLE_ROWS}" >> ${LOG_LOCATION}/${logfile}
            echo "sysbench test duration: ${MAX_TIME} seconds" >> ${LOG_LOCATION}/${logfile}

            cmd="sysbench /usr/local/share/sysbench/${MODE}.lua --tables=${TABLE_COUNT} \
                --table-size=${TABLE_ROWS} --threads=${THREADS} --time=${MAX_TIME} --mysql-host=${HOST_NAME} \
                --mysql-db=dbtest --mysql-user='cavium' --mysql-password='some_pass' \
                --max-requests=0 run >> ${LOG_LOCATION}/${logfile}"
            echo "`date -u` :: ${cmd}" >> cmdline.txt
            echo "1 - Launching [$cmd]"
            eval ${cmd}>/dev/null 2>&1
            echo "done"

            echo -n "Power:" >> ${LOG_LOCATION}/${logfile}

            KILL_MPSTAT
            sleep 30
            cat powerstats.csv >> ${LOG_LOCATION}/${logfile}

            cp power_monitor.log $PWD/${LOG_LOCATION}

            cmd="python monitor.py ${date_folder}-${TABLE_COUNT}-${TABLE_ROWS}-${THREADS} ${pid} \
                $PWD/${LOG_LOCATION}/monitor.log benchlog_fn.log \
                $PWD/${LOG_LOCATION}/monitor.html ${HOST_NAME}"
            eval ${cmd}
        done

        # display the results here
        echo "====================== Results Begin ==========================="
        cat ${LOG_LOCATION}/${logfile}
        echo "====================== Results End ============================="

        cmd="sysbench /usr/local/share/sysbench/${MODE}.lua --tables=${TABLE_COUNT} \
            --mysql-db=dbtest --mysql-host=${HOST_NAME} --mysql-user='cavium' --mysql-password='some_pass' cleanup"

        echo "`date -u` :: ${cmd}" >> cmdline.txt
        eval ${cmd} >/dev/null 2>&1
    done
done

echo "Collecting Results"
scp -r ${USER_NAME}@${HOST_NAME}:/opt/benchmarks/sysbench-mysql/${finalname}/${finalname1}/SERVER_STATS ../

echo 'table_size,tables_count,threads,transactions,transaction/sec,read/write,read/write(/sec),min(ms),avg(ms),max(ms),95th percentile(ms),Max Power(W),Avg Power(W),Energy(J)' > summary.csv


cat */*/*/*-oltp-*.log | egrep " cat|count:|size:|threads:|transactions:|deadlocks|queries|min:|avg:|max:|percentile:|Power:" | tr -d "\n" | sed 's/Number of threads: /,/g' |sed 's/sysbench tables count:/\n/g'|sed 's/sysbench table size:/,/g'| sed 's/[A-Za-z\/]\{1,\}://g'| sed -e 's/queries//g' -e 's/95th//g' -e 's/ per sec.)//g' -e 's/ms//g' -e 's/(//g' -e 's/^.*cat //g' |sed 's/ \{1,\}/,/g'|sed '/./,$!d'>>summary.csv

sort --field-separator=',' -n -k 1,1 -k 2,2 -k 3,3 summary.csv >> summary_sorted.csv

cp *.csv ../
CLEAN_UP
COPY_RESULTS ${WEBSERVER} ${USER_NAME}
