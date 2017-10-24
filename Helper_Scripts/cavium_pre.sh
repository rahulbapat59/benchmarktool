#!/usr/bin/env bash

echo 4096  | sudo tee /proc/sys/net/ipv4/tcp_max_syn_backlog
echo 4096  | sudo tee /proc/sys/net/core/somaxconn
echo 0 | sudo tee /proc/sys/kernel/sched_autogroup_enabled
echo 5000000 | sudo tee /proc/sys/kernel/sched_min_granularity_ns
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo never | sudo tee /sys/kernel/mm/transparent

