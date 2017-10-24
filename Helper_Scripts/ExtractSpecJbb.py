#!/usr/bin/python3

import os
import re

logs_dir = 'C:\cygwin\home\rgadgil\logs\specjbb'
extension = '.raw'
# This is the path where you want to search
path = r'C:\cygwin\home\rgadgil\logs\specjbb'


def do_useful_stuff(results_file_1, path_level2):
    myvars = {}
    # print("start " + results_file_1)
    with open(results_file_1) as my_file:
        for line in my_file:
            if not line.startswith('#'):
                name, var = line.partition("=")[::2]
                myvars[name.strip()] = var
    # print(myvars)
    print(
        myvars['jbb2015.test.aggregate.SUT.totalChips'].strip('\n') + ',' +
        myvars['jbb2015.test.aggregate.SUT.totalCores'].strip('\n') + ',' +
        myvars['jbb2015.test.aggregate.SUT.totalThreads'].strip('\n') + ',' +
        myvars['jbb2015.test.aggregate.SUT.totalMemoryInGB'].strip('\n') + ',' +
        myvars['jbb2015.product.SUT.sw.jvm.jvm_1.version'].strip('\n') + ',' +
        myvars['jbb2015.result.category'].strip('\n') + ',' +
        myvars['jbb2015.result.metric.max-jOPS'].strip('\n') + ',' +
        myvars['jbb2015.result.metric.critical-jOPS'].strip('\n') + ',' +
        results_file_1.strip('\n'))


for root, dirs_list, files_list in os.walk(path):
    for file_name in files_list:
        file_name_path = os.path.join(root, file_name)
        if os.path.splitext(file_name)[-1] == extension:
            prog = re.compile('specjbb2015-C-*')
            if prog.match(file_name):
                # print(file_name)
                do_useful_stuff(file_name_path, file_name_path)
