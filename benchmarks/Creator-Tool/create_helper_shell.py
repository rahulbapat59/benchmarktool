#!/usr/bin/env python3
""""
Project Name : Cavium_BMTool
File Name: create_helper_shell.sh  
Author: rgadgil 
File Created: 09/26/2016   13:04
Details:
"""
import configparser
import os


def create_help_script():
    f = open("../../benchmarks/sysbench-mysql/scrip/server/sysbench-mysql.sh", "w")
    f.write("#!/usr/bin/env bash")


def inplace_change(filename, old_string, new_string):
    with open(filename) as f:
        s = f.read()
        if old_string not in s:
            print('"{old_string}" not found in {filename}.'.format(**locals()))
            return
    with open(filename, 'w') as f:
        print('Changing "{old_string}" to "{new_string}" in {filename}'.format(**locals()))
        s = s.replace(old_string, new_string)
        f.write(s)


def read_config_file(this_test):
    change_files = []
    args_file = "../../config/ListofTests.config"
    config = configparser.ConfigParser()
    config.sections()
    config.read(args_file)
    sub_config = configparser.ConfigParser()
    sub_config.sections()
    if os.path.exists("../../" + config[this_test]['Helpfile']):
        sub_config.read("../../" + config[this_test]['Helpfile'])
        items_in_this_config = sub_config.sections()
        vars_create = ""
        for items in items_in_this_config:
            vars_create += items.upper() + "=" + sub_config[items]['default'] + "\n"
        if config.has_option(this_test, 'Server'):
            change_files.append(this_test + "_server.sh")
        else:
            print("No Server Option")
        if config.has_option(this_test, 'Client'):
            change_files.append(this_test + "_client.sh")
        else:
            print("No Client Option")
        for change_file in change_files:
            os.system("cp shell-template.sh " + change_file)
            inplace_change(change_file, "{VARS_PYTHON_REPLACE}", vars_create)
            short_tip = "s:c:C:w:u:x:y:hv:"
            for items in items_in_this_config:
                short_tip += sub_config[items]['shorttip'].strip("-")
                short_tip += ":"
            inplace_change(change_file, "{GETOPS_PYTHON_SHORTTIP_REPLACE}", short_tip)
            long_tip = "server:,webserver:,username:,client:,prefile:,postfile:,help,verbose_count:"
            for items in items_in_this_config:
                long_tip += ","
                long_tip += sub_config[items]['longtip'].strip("-")
                long_tip += ":"
            inplace_change(change_file, "{GETOPS_PYTHON_LONGTIP_REPLACE}", long_tip)
            option = ""
            for items in items_in_this_config:
                option += "\t\t" + sub_config[items]['shorttip'] + "|" + sub_config[items]['longtip'] + ") " + \
                          items.upper() + "=\"${2//\\'/}\" ; shift;;" + "\n"
            inplace_change(change_file, "{CASE_STATEMENT_PYTHON_REPLACE}", option)
            help_string = ""
            for items in items_in_this_config:
                help_string += "\techo \"${REV}" + sub_config[items]['shorttip'] + " or " + sub_config[items][
                    'longtip'] + \
                               "${NORM} --Sets the value for option ${BOLD}" + sub_config[items]['help'] + \
                               "${NORM}. Default is ${BOLD}" + sub_config[items]['default'] + "${NORM}.\"" + "\n"
            inplace_change(change_file, "{VARS_PYTHON_HELP}", help_string)
            inplace_change(change_file, "${TEST_TYPE}", this_test)
    else:
        print("../../" + config[this_test]['Helpfile'])
        print("File does not exist")


# read_config_file("sysbench-mysql")
# read_config_file("Nginx")
# read_config_file("memcached")
# read_config_file("lmbench-mem")
# read_config_file("lmbench-stream")
# read_config_file("sysbench-fio")
# read_config_file("iperf")
# read_config_file("coremark")
# read_config_file("specint")
read_config_file("multichase")
