#!/usr/bin/env bash

mac_addr=$(ifconfig -a | grep -i [Hh][Ww]addr | cut -d ' ' -f6)
count=0
echo $mac_addr
sudo rm -f /etc/udev/rules.d/10-network.rules
for ma in $mac_addr; do
        echo SUBSYSTEM==\"net\",ACTION==\"add\",ATTR{address}==\"$ma\",NAME=\"eth$count\">>/etc/udev/rules.d/10-network.rules
        count=$(($count+1))
done

