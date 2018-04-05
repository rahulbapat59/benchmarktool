#!/usr/bin/env python3
'''
Project Name : Cavium_BMTool
File Name: create_helper_shell.sh  
Author: rgadgil, blei
File Created: 09/26/2016   13:04
Details:
'''
import argparse
import configparser
import subprocess
import filecmp
import traceback
import os


BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIR_PATH = os.path.join(BASE_DIR, "benchmarks")
LIST_OF_TESTS_TXT = os.path.join(BASE_DIR, "config", "ListofTests.txt")
LIST_OF_TESTS_CONFIG = os.path.join(BASE_DIR, "config", "ListofTests.config")


"""
    INITIALIZATION FUNCTIONS
    These are used entirely by initialize_test().
"""

def generate_directories(test):
    print("\nCreating directories and empty .config file for {0}...".format(test), end='')
    os.makedirs(os.path.join(DIR_PATH, test, "config"), exist_ok=True)
    os.makedirs(os.path.join(DIR_PATH, test, "scripts", "client"), exist_ok=True)
    os.makedirs(os.path.join(DIR_PATH, test, "scripts", "server"), exist_ok=True)


def generate_empty_config(test):
    config_file = os.path.join(DIR_PATH, test, "config", "{0}.config".format(test))
    if os.path.isfile(config_file):
        print("\n[WARNING] Config file already exists.")
        overwrite = input("Clear config file? (y/n or ENTER): ") or 'n'
        if overwrite == 'y':
            open(config_file, 'w').close()
            print("\nConfig file overwritten!")
        else:
            print("\nLeaving config file untouched.")
        print("Stopping initialization process.")
        return "FAILURE"
    else:
        open(config_file, 'a').close()
        print("Complete.\n")
        return "SUCCESS"


def append_to_test_lists(test):
    print("Adding {0} to ListofTests.txt and ListofTests.config...".format(test))
    with open(LIST_OF_TESTS_TXT, "a") as listfile:
        listfile.write(',' + test)
    with open(LIST_OF_TESTS_CONFIG, "a") as listfile:
        helpstring = input("Helpstring (ENTER for default): ") or "Run the {0} benchmark".format(test)
        helpfile = "benchmarks/{0}/config/{0}.config".format(test)
        server = input("Server will run (ENTER for default): ") or test
        client = input("Client will run (ENTER for default): ") or test
        listfile.write("[{0}]\nHelpstring : {1}\nHelpfile : {2}\n".format(test, helpstring, helpfile))
        listfile.write("Server : {0}\nClient : {1}\n\n".format(server, client))
    print("Complete.")


"""
    FILE GENERATION FUNCTIONS
    These are used entirely by generate_files().
"""

# Returns the appropriate file path for a generated test file (e.g. iperf3_server.sh)
def filename(test, template_type, new):
    t_type = template_type.lower()
    if new:
        return os.path.join(DIR_PATH, test, "scripts", t_type, "NEW-{0}_{1}.sh".format(test, t_type))
    else:
        return os.path.join(DIR_PATH, test, "scripts", t_type, "{0}_{1}.sh".format(test, t_type))


# "new_templates" is an out parameter. Files to be generated (client.sh, server.sh) are appended there.
# "template_type" refers to either Server or Client, capitalized.
def get_templates_to_generate(main_config, new_templates, template_type, test):
    do_diff = ""
    if main_config.has_option(test, template_type):
        template_file = filename(test, template_type, new=False)
        if os.path.isfile(template_file):
            do_diff = input(
                template_type + " file already exists.\nGenerate new file and see diff? (y/n or ENTER): ") or 'n'
            if do_diff == 'y':
                print("New file will be generated.\n")
                template_file = filename(test, template_type, new=True)
                new_templates.append(template_file)
            else:
                print("Skipping generation.\n")
        else:
            new_templates.append(template_file)
    else:
        print("No {0} option".format(template_type))
    return do_diff


def print_missing(item, option):
    print("Section [{0}] is missing {1} option.".format(item, option))


def missing_options(test, test_config, test_config_items, template):
    missing_option = False
    for item in test_config_items:
        if not test_config.has_option(item, "required"):
            print_missing(item, "REQUIRED")
            missing_option = True
        if not test_config.has_option(item, "help"):
            print_missing(item, "HELP")
            missing_option = True
        if not test_config.has_option(item, "shorttip"):
            print_missing(item, "SHORTTIP")
            missing_option = True
        if not test_config.has_option(item, "longtip"):
            print_missing(item, "LONGTIP")
            missing_option = True
    return missing_option


def substitute_defaults(test_config, test_config_items, template):
    vars_create = ""
    for item in test_config_items:
        if test_config.has_option(item, "default"):
            vars_create += item.upper() + "=" + test_config[item]['default'] + "\n"
    inplace_change(template, "{VARS_PYTHON_REPLACE}", vars_create)


def substitute_shorttips(test_config, test_config_items, template):
    short_tip = "s:c:C:w:u:x:y:hv:"
    for item in test_config_items:
        short_tip += test_config[item]['shorttip'].strip("-")
        short_tip += ":"
    inplace_change(template, "{GETOPS_PYTHON_SHORTTIP_REPLACE}", short_tip)


def substitute_longtips(test_config, test_config_items, template):
    long_tip = "server:,webserver:,username:,client:,prefile:,postfile:,help,verbose_count:"
    for item in test_config_items:
        long_tip += ","
        long_tip += test_config[item]['longtip'].strip("-")
        long_tip += ":"
    inplace_change(template, "{GETOPS_PYTHON_LONGTIP_REPLACE}", long_tip)


def substitute_options(test_config, test_config_items, template):
    option = ""
    for item in test_config_items:
        option += "\t\t" + test_config[item]['shorttip'] + "|" + test_config[item]['longtip'] + ") " + \
                  item.upper() + "=\"${2//\\'/}\" ; shift;;" + "\n"
    inplace_change(template, "{CASE_STATEMENT_PYTHON_REPLACE}", option)


def substitute_help(test_config, test_config_items, template):
    help_string = ""
    for item in test_config_items:
        default_string = ""
        if test_config.has_option(item, "default"):
            default_string = "${NORM}. Default is ${BOLD}" + test_config[item]['default'] + "${NORM}"
        help_string += "\techo \"${REV}" + test_config[item]['shorttip'] + " or " + test_config[item]['longtip'] + \
                       "${NORM} --Sets the value for option ${BOLD}" + test_config[item]['help'] + \
                       default_string + ".\"\n"
    inplace_change(template, "{VARS_PYTHON_HELP}", help_string)


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


# Compares two files. If different, ask user if they want to patch
def prompt_diff(test, template_type):
    old_file = filename(test, template_type, new=False)
    new_file = filename(test, template_type, new=True)
    if filecmp.cmp(old_file, new_file):
        print("\n!!! NEW {0} FILE IS SAME -- NO CHANGES MADE !!!".format(template_type.upper()))
    else:
        print("\n##################### DIFF OF {0} FILES #####################\n".format(template_type.upper()))
        patch_file = os.path.join(
            DIR_PATH, test, "scripts", template_type, "{0}_{1}.patch".format(test, template_type))
        with open(patch_file, "w") as outfile:
            subprocess.call(["diff", "-uw", old_file, new_file], stdout=outfile)
        subprocess.call(["cat", patch_file])
        print("\n################################################################\n")
        response = input("Patch with new file? (y/n or ENTER): ") or 'n'
        if response == 'y':
            print("PATCH FILE: " + patch_file)
            os.system("patch -b -d/ -p0 < {0}".format(patch_file))
            print("Patch performed.")
        else:
            print("Discarding patch and keeping old files.")
        os.remove(patch_file)
    os.remove(new_file)


"""
    PRIMARY FUNCTIONS
    These are the main three functions used in main().
"""

def get_args():
    parser = argparse.ArgumentParser(description="Creates benchmark directories and generates skeleton code.")
    parser.add_argument('testname', help='Name of test to initialize or generate files for')
    parser.add_argument('-i', '--initialize', action='store_true',
                        help='Initializes test directories (required once)', required=False)
    args = parser.parse_args()
    return args


def initialize_test(test):
    generate_directories(test)
    if generate_empty_config(test) == "SUCCESS":
        append_to_test_lists(test)
        print("\nAdd useful flags to {0}.config, then rerun this script.".format(test))


def generate_files(test):
    print("Generating skeleton files for {0}.\n".format(test))
    main_config = configparser.ConfigParser()
    main_config.read(LIST_OF_TESTS_CONFIG)
    try:
        # Read the test's config file
        test_config = configparser.ConfigParser()
        test_config.read("../../" + main_config[test]['Helpfile'])
        test_config_items = test_config.sections()
        # If .sh files already exist, ask user if they want to generate new ones and perform a diff
        new_templates = [] # Populated by the functions below
        do_server_diff = get_templates_to_generate(main_config, new_templates, 'Server', test)
        do_client_diff = get_templates_to_generate(main_config, new_templates, 'Client', test)
        # Generate template files
        for template in new_templates:
            # Check if all required options are present
            if missing_options(test, test_config, test_config_items, template):
                print("Fix {0}.config and try again -- exiting.".format(test))
                return
            # Create new template file
            subprocess.call(["cp", "shell-template.sh", template])
            # Perform substitutions
            substitute_shorttips(test_config, test_config_items, template)
            substitute_longtips(test_config, test_config_items, template)
            substitute_options(test_config, test_config_items, template)
            substitute_help(test_config, test_config_items, template)
            substitute_defaults(test_config, test_config_items, template)
            inplace_change(template, "${TEST_TYPE}", test)
        # If generated files are NEW, do a diff and ask if user wants to keep
        if do_server_diff == 'y':
            prompt_diff(test, 'server')
        if do_client_diff == 'y':
            prompt_diff(test, 'client')
    except KeyError:
        print("[ERROR] {0} not in ListofTests.config.\n----------".format(test))
        traceback.print_exc()
        print("----------\nFor new tests, first run this script with option -i to initialize.")
    except FileNotFoundError:
        print("[ERROR] Directories for {0} do not exist.\n----------".format(test))
        traceback.print_exc()
        print("----------\nFor new tests, first run this script with option -i to initialize.")


"""
    MAIN FUNCTION
    Calls get_args(), initialize_test(), or generate_files().
"""

def main():
    args_list = get_args()
    test = get_args().testname

    if args_list.initialize:
        initialize_test(test)
    else:
        generate_files(test)


if __name__ == "__main__":
    main()
