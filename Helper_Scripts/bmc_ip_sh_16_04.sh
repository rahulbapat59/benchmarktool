#!/bin/bash
#for CRB-1s system with 16.04
[[ $(id -u) != "0" ]] && {
    echo "You are not root" >&2
    exit 1
}

[[ -c /dev/ipmi0 ]] || {
    modprobe i2c-dev
    insmod /opt/i2c-octeon-4.4.0-31-generic.ko
    modprobe ipmi_msghandler
    modprobe ipmi_devintf
    modprobe ipmi_ssif alerts_broken=1 adapter_name=thunderx-i2c-0.4 addr=0x12
}

ipmitool lan print

