""""
Project Name : Cavium_BMTool
File Name: benchmark.py  
Author: rgadgil 
File Created: 08/22/2016   16:22
Details:
"""
import configparser
import logging
import multiprocessing
import os
import sys
import subprocess
import shlex


log = logging.getLogger(sys.modules['__main__'].__file__)
benchmark_location = "/opt/benchmarks/"


def test_options():
    """
    Populates list of tests from config/ListofTests.txt
    """
    f = open("config/ListofTests.txt", "r")
    lines = f.read().split("\n")
    for line in lines:
        if line != "":
            list_of_tests = line.split(",")
            return list_of_tests
        else:
            sys.exit(0)


def copy_files_to_remote(remote_machine_ip, local_path_to_files, remote_path_to_files, user_name, type_of_run):
    if type_of_run >= 2:
        cmd = "rsync -a " + local_path_to_files + " " + user_name + '@' + remote_machine_ip + ":" + remote_path_to_files
    else:
        cmd = "rsync -a " + local_path_to_files + " " + user_name + '@' + remote_machine_ip + ":" + remote_path_to_files \
              + "> /dev/null 2>&1"
    exec_command(cmd, type_of_run)


def exec_command(command_to_run, verbose_count):
    """"-vvvv : Dry Run = Everything else according to verbosity"""
    if verbose_count is 4:
        print(command_to_run)
    else:
        log.debug(command_to_run)
        os.system(command_to_run)


def exec_bg_command(command_to_run, verbose_count):
    command_to_run = shlex.split(command_to_run)
    if verbose_count is 4:
        print(command_to_run)
    else:
        log.debug(command_to_run)
        return subprocess.Popen(command_to_run)


class ClassBenchmark(object):
    def __init__(self):
        self._last = 0
        self.abs_path_server = ""
        self.abs_path_client = ""

    def parse_args(self, list_of_args, parser):
        # print("in parse args\n")
        args_file = "config/ListofTests.config"
        config = configparser.ConfigParser()
        config.sections()
        config.read(args_file)
        test_valid_options = test_options()
        command_here = list_of_args.args[0]
        x = 0
        for valid_options in test_valid_options:
            if command_here == valid_options:
                break
            else:
                x += 1
        subparsers = parser.add_subparsers()
        # for x in range(len(test_valid_options)):
        sub_options = subparsers.add_parser(test_valid_options[x], help=config[test_valid_options[x]]['Helpstring'])
        sub_config = configparser.ConfigParser()
        sub_config.sections()
        if os.path.exists(config[test_valid_options[x]]['Helpfile']):
            sub_config.read(config[test_valid_options[x]]['Helpfile'])
            items_in_this_config = sub_config.sections()
            valid_types = {"str":str, "int":int, "list":str}
            for items in items_in_this_config:
                flags = [sub_config[items]['shorttip'], sub_config[items]['longtip']]
                extras = {'help':sub_config[items]['help']}
                config_type = sub_config[items]['type']
                # Check if the option is assigned a valid type - int, str, or list
                if config_type in valid_types:
                    extras['type'] = valid_types.get(config_type)
                else:
                    log.error("Invalid config type passed - must be int, str, or list")
                    sys.exit(0)
                # List types pass an extra argument
                if config_type == list:
                    list_options_string = sub_config[items]['choices']
                    list_options = list_options_string.split(",")
                    extras['choices'] = list_options
                    log.debug(list_options)
                # Check if the option has a valid requirement value
                if sub_config.getint(items, 'required') is 1:
                    extras['required'] = True
                    sub_options.add_argument(*flags, **extras)
                elif sub_config.getint(items, 'required') is 0:
                    extras['required'] = False
                    if sub_config.has_option(items, 'default'):
                        extras['default'] = sub_config[items]['default']
                    sub_options.add_argument(*flags, **extras)
                else:
                    log.error("error in config file")
                    sys.exit(0)
        else:
            log.error("Helpfile does not exist")
        log.debug(list_of_args.args)
        list_of_args.command = list_of_args.args[0]
        del list_of_args.args[0]
        args_remainder = sub_options.parse_args(list_of_args.args)
        log.debug(args_remainder)
        return args_remainder, list_of_args.args

    def install(self, list_of_args, clients):
        log.info("Start Installation")
        extra_vars = "--extra-vars \"target=" + list_of_args.server + "\""
        cmd = "ansible-playbook ansible/" + list_of_args.command + "-server-install.yml " + extra_vars
        exec_command(cmd, list_of_args.verbose_count)
        for single_client in clients:
             extra_vars = "--extra-vars \"target=" + single_client + "\""
             cmd = "ansible-playbook ansible/" + list_of_args.command + "-client-install.yml " + extra_vars
             exec_command(cmd, list_of_args.verbose_count)

    def prepare(self, list_of_args, sub_command_args, time_right_now, clients):
        # print("In prepare")
        self.abs_path_server = benchmark_location + list_of_args.command + "/" + list_of_args.comment + "/" + \
                               str(time_right_now) + "/" + "SERVER_STATS"
        cmd = "ssh -l " + list_of_args.username + " " + list_of_args.server + " \"mkdir -p " + self.abs_path_server + "\""
        exec_command(cmd, list_of_args.verbose_count)
        copy_files_to_remote(list_of_args.server, "benchmarks/common/environment.sh", self.abs_path_server,
                             list_of_args.username, list_of_args.verbose_count)
        server_scripts = "benchmarks/" + list_of_args.command + "/scripts/server/*"
        copy_files_to_remote(list_of_args.server, server_scripts, self.abs_path_server, list_of_args.username,
                             list_of_args.verbose_count)
        copy_files_to_remote(list_of_args.server, server_scripts, self.abs_path_server, list_of_args.username,
                             list_of_args.verbose_count)
        client_number = 0
        for single_client in clients:
            self.abs_path_client = benchmark_location + list_of_args.command + "/" + list_of_args.comment + "/" + \
                                   str(time_right_now) + "/" + "client" + str(client_number)
            cmd = "ssh -l " + list_of_args.username + " " + single_client + " \"mkdir -p " + \
                  self.abs_path_client + "\""
            exec_command(cmd, list_of_args.verbose_count)
            if client_number == 0:
                copy_files_to_remote(single_client, "benchmarks/common/*", self.abs_path_client,
                                     list_of_args.username, list_of_args.verbose_count)
                copy_files_to_remote(single_client, "config/powerscripts/*", self.abs_path_client,
                                     list_of_args.username, list_of_args.verbose_count)
                copy_files_to_remote(single_client, "config/hosts.txt", self.abs_path_client,
                                     list_of_args.username, list_of_args.verbose_count)

            client_scripts = "benchmarks/" + list_of_args.command + "/scripts/client/*"
            copy_files_to_remote(single_client, client_scripts, self.abs_path_client,
                                 list_of_args.username, list_of_args.verbose_count)
            client_number += 1
            files_config = configparser.ConfigParser()
            files_config.sections()
            cmd = "benchmarks/" + list_of_args.command + "/config/" + list_of_args.command + "_files.config"
            log.debug(cmd)
            if os.path.exists(cmd):
                files_config.read(cmd)
                list_of_sections = files_config.sections()
                for sections in list_of_sections:
                    list_of_file_options = files_config.options(sections)
                    if 'files_to_copy' in list_of_file_options:
                        files_to_copy = files_config[sections][list_of_file_options[0]].split(",")
                        for file in files_to_copy:
                            path_of_file = "benchmarks/" + list_of_args.command + "/config/" + file + "_" \
                                           + str(sub_command_args.conffile)
                            copy_files_to_remote(list_of_args.server, path_of_file,
                                                 str(self.abs_path_server + "/" + file), list_of_args.username,
                                                 list_of_args.verbose_count)
            else:
                log.info("List of files to copy does not exist")

    def run_client(self, list_of_args, single_client, client_no):
        string_sub_command = " ".join(sys.argv)
        client_path = self.abs_path_client[:-1] + str(client_no)
        cmd = "ssh -l " + list_of_args.username + " " + single_client + " \"cd " + client_path + \
              " && " + "nohup ./" + list_of_args.command + "_client.sh " + string_sub_command + " \""
        exec_command(cmd, list_of_args.verbose_count)

    def run(self, list_of_args, sub_command_args, clients):
        del sys.argv[0]
        string_sub_command = " ".join(sys.argv)
        # print(extra_options)
        cmd = "ssh -l " + list_of_args.username + " " + list_of_args.server + " \"cd " + self.abs_path_server + \
              " && " + "nohup ./" + list_of_args.command + "_server.sh " + string_sub_command + " \""
        #exec_command(cmd, list_of_args.verbose_count) 
        server_cmd = exec_bg_command(cmd, list_of_args.verbose_count)

        pool = multiprocessing.Pool(processes=len(clients))
        client_number = 0

        for single_client in clients:
            pool.apply_async(self.run_client, args=(list_of_args, single_client, client_number), callback=None)
            client_number += 1
        pool.close()
        pool.join()
        # The below kills the server process, but not the iperf3 server it starts...
        server_cmd.terminate()

    def report(self):
        log.info("Start Report Generation")
