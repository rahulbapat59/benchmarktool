#!/usr/bin/env bash

logdate=$(date +%Y-%m-%d,%H:%M:%S)
declare -a power_vec

ipmitool -H ${1} -U ${2} -P ${3} sensor>sensor.txt
V0=$(cat sensor.txt | grep VR_P0_VOUT | cut -d\| -f2)
I0=$(cat sensor.txt | grep VR_P0_IOUT | cut -d\| -f2)
echo ${V0} ${I0}

V0_power=$(echo "${V0} * ${I0}" | bc -l)
Total_power=$(echo "${V0_power}" | bc -l)
printf "${logdate},%f\n" "${Total_power}" >> $4

exit 0

