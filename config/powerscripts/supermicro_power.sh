#!/usr/bin/env bash

logdate=$(date +%Y-%m-%d,%H:%M:%S)

power=$(ipmitool -I lanplus -H ${1} -U ${2} -P ${3} dcmi power reading | grep "Instantaneous power reading:" \
| sed -e 's/Instantaneous power reading:/ /g' | sed 's/ //g' | sed 's/Watts/ /') >/dev/null 2>&1

echo ${logdate},${power}>>$4
