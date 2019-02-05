#!/usr/bin/env python2

import socket
import re
import os
import types
import sys
import subprocess


#hostname = socket.gethostname()
#IPAddr = socket.gethostbyname(hostname)
#print("Computer Name is:" + str(hostname))
#print("Computer IP Address is:" + str(IPAddr))



 # Initializations

#utput = " Interface: %s Speed: %s"
#oinfo = "(Speed Unknown)"
#peed  = noinfo
fp = os.popen("ifconfig -a")
dat=fp.read()

itfs = [section for section in dat.split('\n\n') if section and section != '\n'] # list of interfaces sections, filter the empty sections

for itf in itfs:
        match = re.search('^(\w+)', itf) # search the word at the begining of the section
        interface = match and match.group(1)
        match = re.search('Speed:(\d+)', itf) # search for the field Speed and capture its digital value
        speed = (match and match.group(1)) or 'Speed not found'
        print interface, speed
