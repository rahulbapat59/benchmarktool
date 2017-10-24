    #!/bin/bash

    this_is=${PWD}
    parentdir="$(dirname "${PWD}")"
    logdate=$(date +%Y-%m-%d,%H:%M:%S)
    this_is=${PWD}
    #scp rajiv@${1}:${parentdir}/SERVER_STATS/power_monitor.log .
    scp sm_cpu1.sh rajiv@${1}:${parentdir}/SERVER_STATS
    ssh -l rajiv ${1} "cd ${parentdir}/SERVER_STATS && [ -f power_monitor.log ] || echo "Date,Time,Power">>power_monitor.log"
    ssh -l rajiv ${1} "cd ${parentdir}/SERVER_STATS && ./sm_cpu1.sh $1 $2 $3"
    scp rajiv@${1}:${parentdir}/SERVER_STATS/power_monitor.log .

