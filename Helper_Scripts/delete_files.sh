#!/usr/bin/env bash

find . -name $1 -type f -delete

date_folder=$(dirname $PWD)
finalname=$(basename parentdir="$(dirname "$date_folder")")
finalname1=$(basename parentdir="$(dirname "$PWD")")
ssh cavium@127.0.0.1 mkdir -p /opt/logs/sysbench-mysql/$finalname/$finalname1
rsync -r $date_folder/* cavium@127.0.0.1:/opt/logs/sysbench-mysql/$finalname/$finalname1
ssh -l cavium 127.0.0.1 "sudo chmod -R 777 /opt/logs/sysbench-mysql/"
ssh -l cavium 127.0.0.1 "sudo chmod -R 777 /opt/logs/"
ssh -l cavium 127.0.0.1 "cd /opt/logs/ && python3 create_summary.py"
