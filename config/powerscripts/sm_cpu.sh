#!/bin/bash

sudo modprobe msr

logdate=$(date +%Y-%m-%d,%H:%M:%S)

power=$(ipmitool -I lanplus -H ${1} -U ${2} -P ${3} dcmi power reading | grep "Instantaneous power reading:" \
| sed -e 's/Instantaneous power reading:/ /g' | sed 's/ //g' | sed 's/Watts/ /')

sudo modprobe msr
sudo /home/rajiv/IntelPerformanceCounterMonitor-V2.11/pcm-power.x -- ls | grep "\; Watts:" | cut -d: -f3 | cut -d\; -f1 > sensor.txt
P0=$(tail -1 sensor.txt)
P1=$(tail -2 sensor.txt | head -1)

Total_power=$(echo "${P0} + ${P1}" | bc -l)
echo ${Total_power},${power}
echo ${logdate},${Total_power},${power}>>power_monitor.log


