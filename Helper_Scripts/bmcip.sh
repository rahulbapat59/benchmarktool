#!/usr/bin/env bash
#for pass2-22 with 14.04
modprobe i2c-dev
modprobe ipmi_msghandler
modprobe ipmi_devintf
modprobe ipmi_ssif alerts_broken=1 adapter_name=thunderx-i2c-0.4 addr=0x12 #try between 8 and 15
ipmitool lan print
