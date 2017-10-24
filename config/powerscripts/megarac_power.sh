#!/usr/bin/env bash

logdate=$(date +%Y-%m-%d,%H:%M:%S)

power=$(ipmitool -I lanplus -H ${1} -U ${2} -P ${3} sensor | grep TOTAL_POWER | cut -d\| -f2)

echo ${logdate},${power}>>$4
