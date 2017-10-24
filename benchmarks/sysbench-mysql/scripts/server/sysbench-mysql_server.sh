#!/usr/bin/env bash

ulimit -n 10000

set +x
SCRIPT=`basename ${BASH_SOURCE[0]}`

LOCALIP=localhost
BASEDIR=/usr
DATADIR=/opt/benchmarks/mysql_data
MYSQLDDIR=/usr/sbin
MYSQLDIR=/usr/bin
MAXTIME=120
TABLECOUNT=1
TABLEROW=10000
THREADLIST=1
MODE=oltp_read_only
CONFFILE=2
var_pidof=$(which pidof)

function HELP() {
    NORM=`tput -T xterm sgr0`
    BOLD=`tput -T xterm bold`
    REV=`tput -T xterm smso`
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
    ssh ${USER_NAME}@${WEBSERVER} mkdir -p /opt/logs/sysbench-mysql/${finalname}/${finalname1}
    rsync -r ${date_folder}/* ${USER_NAME}@${WEBSERVER}:/opt/logs/sysbench-mysql/${finalname}/${finalname1}
    ssh -l ${USER_NAME} ${WEBSERVER} "cd /opt/logs/ && python3 create_summary.py"
    echo "Test Ended"
    echo "LOOK FOR THE RESULTS AT THE RESULTS at http://${WEBSERVER}/$sysbench-mysql/${finalname}/${finalname1}"
    exit 1
}

function START_POWER_MONITOR(){
            touch $PWD/power_monitor.log
            for pid in `${var_pidof} mpstat`
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
            touch $PWD/monitor.log
            mpstat -P ALL 5 | tr -s " " | sed 's/ /,/g' | grep -v '^$' | \
		 grep -v -e '^[A-Z][a-z].*' >> stat.csv &

	    for pid in `pidof mpstat`
            do
                echo ${pid}>/dev/null 2>&1
            done
            cmd="python monitor.py ${date_folder} $pid ${PWD}/monitor.log \
                benchlog_fn.log ${PWD}/monitor.html ${1}"
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

    sudo killall mpstat
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
		-m|--maxtime) MAXTIME="${2//\'/}" ; shift;;
		-tc|--tablecount) TABLECOUNT="${2//\'/}" ; shift;;
		-tr|--tablerow) TABLEROW="${2//\'/}" ; shift;;
		-tl|--threadlist) THREADLIST="${2//\'/}" ; shift;;
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

for pid in `pidof mysqld`
do
	sudo /etc/init.d/mysql stop>/dev/null 2>&1
	sudo kill -9 ${pid}>/dev/null 2>&1
done

if  cat /etc/apparmor.d/local/usr.sbin.mysqld | grep -Fxq "${DATADIR}/ r, #Added by Benchmarktool"; then
    sudo /etc/init.d/apparmor stop>/dev/null 2>&1
    sudo chmod 646 /etc/apparmor.d/local/usr.sbin.mysqld
    sudo echo "${DATADIR}/ r, #Added by Benchmarktool" >> /etc/apparmor.d/local/usr.sbin.mysqld
    sudo echo "${DATADIR}/** rwk, #Added by Benchmarktool" >> /etc/apparmor.d/local/usr.sbin.mysqld
    sudo chmod 644 /etc/apparmor.d/local/usr.sbin.mysqld
fi

if cat /etc/apparmor.d/local/usr.sbin.mysqld | grep -Fxq "/opt/benchmarks/sysbench-mysql/** r, #Added by Benchmarktool"; then
    sudo /etc/init.d/apparmor stop>/dev/null 2>&1
    sudo chmod 646 /etc/apparmor.d/local/usr.sbin.mysqld
    sudo echo "/opt/benchmarks/sysbench-mysql/** r, #Added by Benchmarktool" >> /etc/apparmor.d/local/usr.sbin.mysqld
    sudo chmod 644 /etc/apparmor.d/local/usr.sbin.mysqld
fi

if cat /etc/apparmor.d/local/usr.sbin.mysqld | grep -Fxq "/opt/benchmarks/mysqld1.pid rw, #Added by Benchmarktool"; then
    sudo /etc/init.d/apparmor stop>/dev/null 2>&1
    sudo chmod 646 /etc/apparmor.d/local/usr.sbin.mysqld
    sudo echo "/opt/benchmarks/mysqld1.pid rw, #Added by Benchmarktool" >> /etc/apparmor.d/local/usr.sbin.mysqld
    sudo echo "/opt/benchmarks/mysqld1.sock rw, #Added by Benchmarktool" >> /etc/apparmor.d/local/usr.sbin.mysqld
    sudo echo "/opt/benchmarks/mysqld1.sock.lock rw, #Added by Benchmarktool" >> /etc/apparmor.d/local/usr.sbin.mysqld
    sudo chmod 644 /etc/apparmor.d/local/usr.sbin.mysqld
fi

sudo /etc/init.d/apparmor restart>/dev/null 2>&1

echo -e "basedir = ${BASEDIR}\n" >> mysqld.cnf
echo -e "datadir = ${DATADIR}\n" >> mysqld.cnf
echo -e "user = ${USERNAME}\n" >> mysqld.cnf
sudo rm -f -r ${DATADIR}
mkdir -p ${DATADIR}
chmod -R 777 ${DATADIR}
sudo chmod 755 mysqld.cnf>/dev/null 2>&1
sudo chmod 755 /opt/benchmarks/mysqld1.sock>/dev/null 2>&1
sleep 1
${MYSQLDDIR}/mysqld --defaults-file=mysqld.cnf --initialize-insecure 1>mysqloutput.log 2>&1
${MYSQLDDIR}/mysqld --defaults-file=mysqld.cnf 1>>mysqloutput.log 2>&1 &
sleep 5
echo "Starting Server"
Q0="FLUSH PRIVILEGES;"
Q1="CREATE USER 'cavium'@'localhost' IDENTIFIED BY 'some_pass';"
Q2="GRANT ALL PRIVILEGES ON *.* TO 'cavium'@'localhost' WITH GRANT OPTION;"
Q3="CREATE USER 'cavium'@'%' IDENTIFIED BY 'some_pass';"
Q4="GRANT ALL PRIVILEGES ON *.* TO 'cavium'@'%' WITH GRANT OPTION;"
Q5="CREATE DATABASE IF NOT EXISTS dbtest;"
Q6="CREATE DATABASE IF NOT EXISTS sbtest;"
Q7="FLUSH PRIVILEGES;"

SQL="${Q1}${Q2}${Q3}${Q4}${Q5}${Q6}${Q7}"

${MYSQLDIR}/mysql -S /opt/benchmarks/mysqld1.sock -u root -e "$SQL"
${MYSQLDIR}/mysql -S /opt/benchmarks/mysqld1.sock -u root -e "SHOW GLOBAL VARIABLES" >show_global_variables.txt 2>&1
${MYSQLDIR}/mysql -S /opt/benchmarks/mysqld1.sock -u root -e "SHOW GLOBAL STATUS" >show_global_status.txt 2>&1
${MYSQLDIR}/mysql -S /opt/benchmarks/mysqld1.sock -u root -e "SHOW ENGINE INNODB STATUS\G" >show_engine_innodb_status.txt 2>&1
${MYSQLDIR}/mysql -S /opt/benchmarks/mysqld1.sock -u root -e "set global max_prepared_stmt_count=1000000" 2>&1


./environment.sh ${MYSQLDDIR} ${MYSQLDIR} &

sudo ${MYSQLDIR}/mysql -u root --version >> environment_versions.txt
exit 0
