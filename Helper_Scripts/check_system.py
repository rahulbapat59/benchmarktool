""""
Project Name : Cavium_BMTool
File Name: check_system.py  
Author: rgadgil 
File Created: 08/02/2016   09:31
Details:
"""

import configparser
import shlex
import smtplib
import subprocess
from time import gmtime, strftime


def email_sender(input_message, email_to, client):
    """ function to send email """
    body = input_message + client

    to = email_to
    gmail_user = 'caviummonitoring@gmail.com'  # email of sender account
    gmail_pwd = 'cavium0502'  # password of sender account
    smtpserver = smtplib.SMTP("smtp.gmail.com", 587)
    smtpserver.ehlo()
    smtpserver.starttls()
    smtpserver.ehlo
    smtpserver.login(gmail_user, gmail_pwd)
    header = 'To:' + to + '\n' + 'From: ' + gmail_user + '\n' + 'Subject:Server Down! ' + '\n' + client + '\n'
    # input_message = input_message + client
    msg = header + input_message
    smtpserver.sendmail(gmail_user, to, msg)
    smtpserver.close()

machines = []
hosts_file = "hosts.txt"
config_hosts = configparser.ConfigParser()
config_hosts.read(hosts_file)
hosts_this = config_hosts.sections()
machines_down = []
send_mail = 0
for each_section in config_hosts.sections():
    machines.append(each_section)
for machine in machines:
    # print(machine)
    if machine in hosts_this:
        if config_hosts.has_option(machine, 'IP'):
            machine_ip = config_hosts[machine]['IP']
            cmd = shlex.split(str("ping -c 2 ") + machine_ip)
        else:
            machine = config_hosts[machine]['IP']
            cmd = shlex.split(str("ping -c 2 ") + machine)
        try:
            output = subprocess.check_output(cmd)
        except subprocess.CalledProcessError:
            print("The IP " + machine + " is Not Reachable")
            machines_down.append(machine)
            send_mail =1
            pass
        else:
            print("The IP " + machine + " is Reachable")
    else:
        print("Wrong Config File")

if send_mail == 1:
    message = str(" are down" + strftime("%d %b %Y %X +0000", gmtime()))
    print(message)
    listofmachines = '\n'.join(machines_down)
    print(listofmachines)
    email_sender(str("Above Servers Not Reachable "), "rajeev.gadgil@caviumnetworks.com", listofmachines)
    email_sender(str("Above Servers Not Reachable "), "Shay.Galon@cavium.com", listofmachines)
