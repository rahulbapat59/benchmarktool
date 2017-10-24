#!/usr/bin/env bash
#Hostname to change the system hostname
sudo echo $1>/etc/hostname

sudo echo "127.0.0.1 localhost">/etc/hosts
sudo echo "127.0.0.1 $1">>/etc/hosts
sudo echo "::1     localhost ip6-localhost ip6-loopback">>/etc/hosts
sudo echo "ff02::1 ip6-allnodes">>/etc/hosts
sudo echo "ff02::2 ip6-allrouters">>/etc/hosts
