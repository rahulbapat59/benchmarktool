""""
Project Name : Cavium_BMTool
File Name: send_email_system.py  
Author: rgadgil 
File Created: 08/02/2016   10:15
Details:
"""

import smtplib
import time
from threading import Thread

import requests  ## install requests


# email sending function
def email_sender(input_message, email_to, client):
    """ function to send email """
    to = email_to
    gmail_user = 'caviummonitoring@gmail.com'  # email of sender account
    gmail_pwd = 'cavium0502'  # password of sender account
    smtpserver = smtplib.SMTP("smtp.gmail.com", 587)
    smtpserver.ehlo()
    smtpserver.starttls()
    smtpserver.ehlo
    smtpserver.login(gmail_user, gmail_pwd)
    header = 'To:' + to + '\n' + 'From: ' + gmail_user + '\n' + 'Subject:site down! \n'
    input_message = input_message + client
    msg = header + input_message
    smtpserver.sendmail(gmail_user, to, msg)
    smtpserver.close()


# list of sites to track along with email address to send the alert
clients = {"10.18.240.165": "rajeev.gadgil@caviumnetworks.com",
           "pass2-25": "rajeev.gadgil@caviumnetworks.com",
           }

# temporary dictionary used to do separate monitoring when a site is down
temp_dic = {}


# site 'up' function
def site_up():
    """function to monitor up time"""
    while True:
        for client, email in clients.items():
            try:
                r = requests.get(client)
                if r.status_code == 200:
                    print(client, 'Site ok')
                    time.sleep(60)  # sleep for 1 min
                else:
                    print(client, 'Server first registered as down - added to the "server down" monitoring')
                    temp_dic[client] = email
                    del clients[client]
            except requests.ConnectionError:
                print(client, 'Server first registered as down - added to the "server down" monitoring')
                temp_dic[client] = email
                del clients[client]


def site_down():
    """ function to monitor site down time """
    while True:
        time.sleep(900)  # sleeps 15 mins
        for client, email in temp_dic.items():
            try:
                r = requests.get(client)
                if r.status_code == 200:
                    print(client, 'Site is back up!!')
                    email_sender('Site back up!! ', email, client)
                    clients[client] = email
                    del temp_dic[client]
                else:
                    email_sender('Server down!! ', email, client)
                    print(client, 'Server Currently down - email sent')
            except requests.ConnectionError:
                email_sender('Server down!! ', email, client)
                print(client, 'Server Currently down - email sent')


t1 = Thread(target=site_up)
t2 = Thread(target=site_down)
t1.start()
t2.start()
