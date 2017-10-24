#!/usr/bin/env bash

logdate=$(date +%Y-%m-%d,%H:%M:%S)
declare -a power_vec

power_vec=($(ipmitool -H ${1} -U ${2} -P ${3} -I lanplus raw 0x30 0xe2 0x01 0x00 0x00))

ipmitool -H ${1} -U ${2} -P ${3} sensor>sensor.txt
V0=$(cat sensor.txt | grep VR_P0_VOUT | cut -d\| -f2)
V1=$(cat sensor.txt | grep VR_P1_VOUT | cut -d\| -f2)
I0=$(cat sensor.txt | grep VR_P0_IOUT | cut -d\| -f2)
I1=$(cat sensor.txt | grep VR_P1_IOUT | cut -d\| -f2)
echo ${V0} ${V1} ${I0} ${I1}

V0_power=$(echo "${V0} * ${I0}" | bc -l)
V1_power=$(echo "${V1} * ${I1}" | bc -l)
Total_power=$(echo "${V0_power} + ${V1_power}" | bc -l)
printf "${logdate},%f,%d\n" "${Total_power}" "0x${power_vec[2]}${power_vec[1]}" >> $4

exit 0

