#!/usr/bin/env python3
""""
Project Name : Cavium_BMTool
File Name: create_helper_shell.sh  
Author: rgadgil, blei
File Created: 09/26/2016   13:04
Details:
"""
import argparse
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


def get_args():
    parser = argparse.ArgumentParser(description="Creates benchmark directories and generates skeleton code.")
    parser.add_argument('testname', help='Name of test to initialize or generate files for')
    parser.add_argument('-i', '--initialize', action='store_true', help='Initializes test directories (required once)', required=False)

    args = parser.parse_args()
    return args


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
            # Move generated files to the correct directories
            if os.path.isfile("./{0}_client.sh".format(this_test)):
                os.rename("./{0}_client.sh".format(this_test), "../{0}/scripts/client/{0}_client.sh".format(this_test))
            if os.path.isfile("./{0}_server.sh".format(this_test)):
                os.rename("./{0}_server.sh".format(this_test), "../{0}/scripts/server/{0}_server.sh".format(this_test))
    else:
        print("../../" + config[this_test]['Helpfile'])
        print("File does not exist")

args_list = get_args()
test = args_list.testname
if args_list.initialize:
    print("\nCreating directories and empty .config file for {0}...".format(test), end='')
    os.makedirs('../{0}/config'.format(test), exist_ok=True)
    os.makedirs('../{0}/scripts/client'.format(test), exist_ok=True)
    os.makedirs('../{0}/scripts/server'.format(test), exist_ok=True)
    open('../{0}/config/{0}.config'.format(test), 'a').close()
    print("Complete.\n")
    print("Adding {0} to ListofTests.txt and ListofTests.config...".format(test))
    with open("../../config/ListofTests.txt", "a") as listfile:
        listfile.write((',' + test).rstrip('\n'))
    with open("../../config/ListofTests.config", "a") as listfile:
        helpstring = input("Helpstring (ENTER for default): ")
        if not helpstring:
            helpstring = "Run the {0} benchmark".format(test)
        helpfile = "/benchmarks/{0}/config/{0}.config".format(test)
        server = input("Server will run (ENTER for default): ")
        client = input("Client will run (ENTER for default): ")
        if not server:
            server = test
        if not client:
            client = test
        listfile.write("[{0}]\nHelpstring : {1}\nHelpfile : {2}\n".format(test, helpstring, helpfile))
        listfile.write("Server : {0}\nClient : {1}\n\n".format(server, client))
    print("Complete.")
    print("\nAdd useful flags to {0}.config, then rerun this script.".format(test))
else:
    print("Generating skeleton files for {0}.".format(test))
    read_config_file(test)
