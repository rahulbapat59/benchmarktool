#!/usr/bin/env bash

sudo apt update
sudo apt install python build-essential htop ethtool linux-tools-common sysstat ipmitool lmbench \
bc linux-tools-generic libmysqlclient-dev automake autoconf libtool libev-dev hdparm libgnutls28-dev numactl
wget http://repo.cavium.com/ubuntu/repo/binary/mysql-server-cavium.deb
dpkg -x mysql-server-cavium.deb mysql-server-cavium
git clone https://github.com/akopytov/sysbench
cd sysbench
sudo ./autogen.sh
sudo ./configure
sudo make
sudo make install
