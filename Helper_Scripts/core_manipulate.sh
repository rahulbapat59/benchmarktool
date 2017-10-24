#!/usr/bin/env bash

STATUS=$1

for x in /sys/devices/system/cpu/cpu*/online; do
  echo $1 >"$x"
done
