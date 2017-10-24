#!/bin/bash

logdate=$(date +%Y-%m-%d,%H:%M:%S)
sudo modprobe msr
sudo /home/rajiv/IntelPerformanceCounterMonitor-V2.11/pcm-power.x -- ls | grep "\; Watts:" | cut -d: -f3 | cut -d\; -f1 > sensor.txt
P0=$(tail -1 sensor.txt)

Total_power=$(echo "${P0}" | bc -l)

echo ${logdate},${Total_power}>>power_monitor.log

