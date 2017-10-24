#!/usr/bin/python3
""""
Project Name : BenchmarkTool
File Name: Rajeev
Author: rgadgil
File Created: 07/11/2016   13:25
Details: This is the top level file that will copy and create the folders and files into the server and client machines.
This file populates a the list of available tests and also the correct help options for each argument passed.
"""

import argparse
import configparser
import datetime
import getpass
import logging
import os
import pipes
import subprocess
import sys
import time

import benchmarks.common.benchmark

module = sys.modules['__main__'].__file__
log = logging.getLogger(module)


def get_args():
    """
    Parses the arguments from the list of arguments.
    """
    list_of_tests = benchmarks.common.benchmark.test_options()
    my_user = getpass.getuser()
    my_webserver = 'localhost'
    parser = argparse.ArgumentParser(
        description='Script Copies files to remote machines and executes ' + str(list_of_tests) + ' tests')
    parser.add_argument(
        '-s', '--server', type=str, help='Server addresses.', required=True)
    parser.add_argument(
        '-c', '--client', type=str, help='List of comma separated client machine addresses.',
        required=False)
    parser.add_argument(
         '-u', '--username', type=str, help='Username of the user who will execute the tests. \
         The keys for the user need to be present in the system by using for eg: ssh-copy-id', required=False,
        default=my_user)
    parser.add_argument(
        '-w', '--webserver', type=str, help='Webserver IP address', required=False, default=my_webserver)
    parser.add_argument(
        '-x', '--prefile', type=argparse.FileType('r'), help='Prefile to be run before the test', required=False)
    parser.add_argument(
        '-y', '--postfile', type=argparse.FileType('r'), help='Postfile to be run for cleanup afer the test',
        required=False)
    parser.add_argument(
        '-C', '--comment', type=str, help='Comment by which the results will be stored', required=False,
        default="default_comment")
    parser.add_argument("-v", "--verbose", dest="verbose_count", action="count", default=0,
                        help="increases log verbosity for each occurence.")
    parser.add_argument("--with_install", dest="with_install", action="store_true", default=False,
                        help="Install packages to remote machines")
    parser.add_argument("--with_vm", dest="with_vm", action="store_true", default=False,
                        help="Runs the same commands on all VMs")

    # parser.add_argument("command")
    parser.add_argument('args', nargs=argparse.REMAINDER)
    args, leftover = parser.parse_known_args()
    return args, leftover, parser


def release_machine(machine, user):
    """
    Checks if the /etc/motd file exists. If not write to it.
    """
    ssh_host = user + "@" + machine
    file = "/etc/motd"
    resp = subprocess.call(
        ['ssh', ssh_host, 'sudo rm -f -r ' + pipes.quote(file)])


def check_if_machine_in_use(machine, user):
    """
    Checks if the /etc/motd file exists. If not write to it.
    """
    ssh_host = user + "@" + machine
    file = "/etc/motd"
    resp = subprocess.call(
        ['ssh', ssh_host, 'test -e ' + pipes.quote(file)])
    if resp == 0:
        log.error('%s exists. Machine in use' % file)
        sys.exit(0)
    else:
        log.info('%s does not exist' % file)
        os.system("ssh -l " + user + " " + machine + " " + "\"echo \"SYSTEM UNDER TEST : " \
                  + user + "***************************************\" | sudo tee /etc/motd\"")


def check_machine(machines):
    """
    Checks the hosts file to populate the options for each host in the config file
    """
    hosts_file = "config/hosts.txt"
    config_hosts = configparser.ConfigParser()
    config_hosts.read(hosts_file)
    hosts_this = config_hosts.sections()
    for machine in machines:
        if machine in hosts_this:
            if config_hosts.has_option(machine, 'IP'):
                machine = config_hosts[machine]['IP']
            response = os.system("/bin/ping -c 4 " + machine + ">/dev/null 2>&1")
            #response = os.system("ping " + machine + ">/dev/null 2>&1")
            if response == 0:
                log.info(str(machine + ' is up!'))
            else:
                log.error(str(machine + ' is down!'))
                sys.exit(0)
        else:
            log.error("Systems are not part of configuration")
            sys.exit(0)
    log.info("Servers are part of Config")


def main():
    """
        Sets up logging steps.
        Prepare servers and clients to runn the scripts on.
        Take other steps like initiate the copying of files check if machines are up and run the scripts.
    """

    if len(sys.argv) > 1:
        args_list, remained_args, main_parser = get_args()
    else:
        logging.error("Use --help or -h for help")
        sys.exit(0)
    if args_list.verbose_count == 0:
        logging.basicConfig(stream=sys.stderr, level=logging.WARN, format='%(name)s (%(levelname)s): %(message)s')
        # log.warning("Verbosity set to WARN")
    elif args_list.verbose_count == 1:
        logging.basicConfig(stream=sys.stderr, level=logging.INFO, format='%(name)s (%(levelname)s): %(message)s')
        log.info("Verbosity set to INFO")
    elif args_list.verbose_count == 4:
        logging.basicConfig(stream=sys.stderr, level=logging.WARN, format='%(name)s (%(levelname)s): %(message)s')
        log.info("Verbosity set to ERROR")
    else:
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG, format='%(name)s (%(levelname)s): %(message)s')
        log.debug("Verbosity set to DEBUG")
    ts = time.time()
    time_string = datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d_%H-%M-%S')
    log.debug("Current time is " + time_string)

    if args_list.comment == 'default_comment':
        args_list.comment = "comment_" + time_string
    if args_list.client is None:
        args_list.client = args_list.server
        log.warning("Using same server and client since client not specified")
    log.debug(args_list)
    servers_list = list()
    servers_list.append(args_list.server)
    c_machines_l = args_list.client.split(",")
    for c_machines in c_machines_l:
        servers_list.append(c_machines)
    log.debug(servers_list)
    print("Preparing Machines and Tests")
    if args_list.verbose_count != 4:
        check_machine(servers_list)
        check_if_machine_in_use(args_list.server, args_list.username)

    if args_list.prefile is not None:
        log.debug('The file name is {}'.format(args_list.prefile))
        cmd = "rsync -a " + args_list.prefile.name + " " + args_list.username + "@" + args_list.server + \
              ":/opt"
        benchmarks.common.benchmark.exec_command(cmd, args_list.verbose_count)
        cmd = "ssh -l " + args_list.username + " " + args_list.server + " cd /opt/ && ./" + args_list.prefile.name
        benchmarks.common.benchmark.exec_command(cmd, args_list.verbose_count)

    try:
        bm = benchmarks.common.benchmark.ClassBenchmark()
        sub_command_namespace, sub_command_list = bm.parse_args(args_list, main_parser)
        if args_list.with_install is True:
            bm.install(args_list, c_machines_l)
        bm.prepare(args_list, sub_command_namespace, time_string, c_machines_l)
        print("Launching Test")
        bm.run(args_list, sub_command_list, c_machines_l)
    except KeyboardInterrupt:
        log.error('Program interrupted!')
    finally:
        print("Ending Test")
        if args_list.postfile is not None:
            log.debug('The file name is {}'.format(args_list.postfile))
            cmd = "rsync -a " + args_list.postfile.name + " " + args_list.username + "@" + args_list.server + \
                  ":/opt"
            benchmarks.common.benchmark.exec_command(cmd, args_list.verbose_count)
            cmd = "ssh -l " + args_list.username + " " + args_list.server + " cd /opt/ && ./" + args_list.postfile.name
            benchmarks.common.benchmark.exec_command(cmd, args_list.verbose_count)
        release_machine(args_list.server, args_list.username)
        sys.exit(0)
        logging.shutdown()

if __name__ == "__main__":
    sys.exit(main())
