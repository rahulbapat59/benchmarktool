#!/bin/bash

lscpu > lscpu.txt
uname -a > uname.txt
lsb_release -a > lsb_release.txt < /dev/null 2>&1
df -P "${1}"  | awk '/^\/dev/ {print $1}' > partition.txt
value=`cat partition.txt`
sudo hdparm -I $value >disk_details.txt
sudo dmidecode >dmidecode_data.txt
sudo sysctl -a >sysctl.txt < /dev/null 2>&1
sudo ulimit -a > ulimit.txt </dev/null 2>&1
if [ -f /boot/config-`uname -r` ] ; then cat /boot/config-`uname -r` > kernel_config.txt ; fi
if [ -f /proc/config.gz ] ; then zcat /proc/config.gz > kernel_config.txt ; fi