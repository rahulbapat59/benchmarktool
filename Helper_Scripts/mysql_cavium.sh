#!/usr/bin/env bash

echo 4096  | sudo tee /proc/sys/net/ipv4/tcp_max_syn_backlog
echo 4096  | sudo tee /proc/sys/net/core/somaxconn
echo 0 | 
sudo sysctl kernel.sched_autogroup_enabled=0
sudo sysctl kernel.sched_min_granularity_ns=5000000
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag