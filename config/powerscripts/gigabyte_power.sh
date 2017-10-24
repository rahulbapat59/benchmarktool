#!/usr/bin/env bash

logdate=$(date +%Y-%m-%d,%H:%M:%S)
declare -a power_vec

power_vec=($(ipmitool -H ${1} -U ${2} -P ${3} -I lanplus raw 0x30 0xe2 0x01 0x00 0x00))

printf "${logdate},%d\n" "0x${power_vec[2]}${power_vec[1]}" >> $4

exit 0

