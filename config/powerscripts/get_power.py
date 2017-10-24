import configparser
import csv
import logging
import os
import sys
from datetime import datetime
from time import sleep

log = logging.getLogger('get_power')
log.setLevel(logging.INFO)


def show_usage():
    """
    Displays Usage function for get_monitor.py function.
    """
    log.error("Usage:get_monitor.py <parent_pid> <log_path.log> <monitor_node_name1> ... <monitor_node_nameN>")


def start_power_monitor(logging_path, monitor_nodes, pid_mon):
    """
    This function parses the configuration file hosts.txt and updates BMC Addresses and BMC Username Passwords.
    Through the BMC interface the function captures the power readings.
    """
    hosts_file = "hosts.txt"
    config_hosts = configparser.ConfigParser()
    config_hosts.read(hosts_file)
    hosts_this = config_hosts.sections()
    for machine_this in monitor_nodes:
        if machine_this in hosts_this:
            if config_hosts.has_option(machine_this, 'BMC_IP'):
                machine = config_hosts[machine_this]['BMC_IP']
                log.info(str('BMC IP is ' + machine))
            else:
                log.error('Error in Hosts Config File')
                sys.exit(0)
            response = os.system("ping -c 4 " + machine + ">/dev/null 2>&1")
            if response == 0:
                log.info(str(machine_this + ' BMC Reached!'))
                if config_hosts.has_option(machine_this, 'BMC_USER_NAME') \
                        and config_hosts.has_option(machine_this, 'BMC_PASSWORD') \
                        and config_hosts.has_option(machine_this, 'BMC_TYPE'):
                    machine_username = config_hosts[machine_this]['BMC_USER_NAME']
                    machine_password = config_hosts[machine_this]['BMC_PASSWORD']
                    machine_type = config_hosts[machine_this]['BMC_TYPE']
                    # cmd = "echo \"Date,Time,Power,SysPower\" >" + logging_path
                    cmd = "echo \"Date,Time,Power\" >" + logging_path
                    os.system(cmd)
                    cmd = './' + machine_type + '_power.sh ' + machine + ' ' + machine_username + \
                          ' ' + machine_password + ' ' + logging_path
                    while os.path.exists("/proc/%s" % pid_mon):
                        os.system(cmd)
                        sleep(5)
                else:
                    log.error('Error in Hosts Config File')
                    sys.exit(0)
            else:
                log.error(str(machine_this + ' BMC not Reached!'))
                sys.exit(0)
        else:
            log.error("BMC IP could not be reached")
            sys.exit(0)


def generate_report(power_path):
    """
    For a particular run this captures the max energy the min energy and the estimated energy consumed during the test
    The csv file generated will have the power stats.
    """
    max_power = 0
    total_power = 0
    total_syspower = 0
    max_syspower = 0
    number = 0
    reader = csv.DictReader(open(power_path))
    log.info("Report Generation Started")
    for row in reader:
        try:
            if number is 0:
                start_time = datetime.strptime((str(row['Date'] + "," + row['Time'])), "%Y-%m-%d,%H:%M:%S")
                log.debug(start_time)
            try:
                power = float(row['Power'])
            except:
                pass
            # try:
            #     syspower = float(row['SysPower'])
            # except:
            #     pass
            # total_syspower += syspower
            total_power += power
            if max_power <= power:
                max_power = power
                # if max_syspower <= syspower:
                #     max_syspower = syspower
        except ValueError:
            pass
        number += 1
    end_time = datetime.strptime((str(row['Date'] + "," + row['Time'])), "%Y-%m-%d,%H:%M:%S")
    log.debug(end_time)
    log.info("Max_power " + str(max_power))
    delta_time = end_time - start_time
    log.debug(delta_time)

    avg_power = float(total_power/number)
    log.info("Avg Power " + str(avg_power))
    energy = float(avg_power * delta_time.total_seconds())
    log.info("Energy " + str(energy))

    # avg_syspower = float(total_syspower / number)
    # log.info("Avg Power SYS " + str(avg_syspower))
    # energy_sys = float(avg_syspower * delta_time.total_seconds())
    # log.info("Energy SYS " + str(energy_sys))
    with open("powerstats.csv", 'w') as csvfile:
        # csvfile.write(("," + str(max_power) + "," + str(format(avg_power, '.2f')) + "," + str(format(energy, '.2f'))) \
        #               + ("," + str(max_syspower) + "," + str(format(avg_syspower, '.2f')) + "," + \
        #                  str(format(energy_sys, '.2f'))))
        csvfile.write(("," + str(max_power) + "," + str(format(avg_power, '.2f')) + "," + str(format(energy, '.2f'))))

if __name__ == "__main__":
    if len(sys.argv) < 3:
        show_usage()
        sys.exit(1)

    # log(sys.argv)
    global log_path
    global report_path
    global na

    parent_pid = sys.argv[1]
    log_path = sys.argv[2]
    nodes_to_monitor = sys.argv[3:]
    start_power_monitor(log_path, nodes_to_monitor,parent_pid)
    generate_report(log_path)
    sys.exit(0)
