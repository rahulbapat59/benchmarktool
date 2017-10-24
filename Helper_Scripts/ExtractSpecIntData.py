#!/usr/bin/python3

import csv
import os
import re

logs_dir = 'C:\cygwin\home\rgadgil\specintlogs'
extension = '.csv'
# This is the path where you want to search
path = r'C:\cygwin\home\rgadgil\specintlogs'


def do_useful_stuff(results_file_1, path_level2):
    Machine_name = ' '
    Machine_aarch = ' '
    flags = ' '
    KernelVersion = ' '
    numberOfCpus = ' '
    DDRMemTotal = ' '
    freq = ' '
    print(results_file_1)
    try:
        if os.path.exists(results_file_1):
            i = 0
            file_read = open(results_file_1, 'r')
            for i in range(0, 4):
                file_read.readline()
                i += 1
            list1 = []
            i = 0
            for i in range(0, 13):
                list1.append(file_read.readline())
                i += 1
            file_read.close()
            uname_flag = 0
            with open(results_file_1) as f:
                for line in f:
                    if 'Operating System"' in line:
                        uname_flag = 1
                    elif uname_flag == 1:
                        uname_flag = 0
                        KernelVersion = line.strip('\n')
                    elif 'MemTotal:' in line:
                        newline = re.sub(' +', ' ', line)
                        DDRMemTotal = newline.split(':')[1].strip('\n').strip('"')

            # uname_flag = 0
            # for row in list1:
            #     print(row)
            csv_dictionary = csv2dictionary(list1)
            x_product = 1.0
            x_geometric_mean = 1.0
            total_errors = 1.0
            with open(results_file_1) as f:
                for line in f:
                    if "running on" in line:
                        Machine_name = line.split("running on")[1].split()[0]
                        # print(Machine_name)
            lscpu_file = path_level2 + 'lscpu.log'
            try:
                with open(lscpu_file) as f:
                    for line in f:
                        if "Architecture" in line:
                            newline = re.sub(' +', ' ', line)
                            Machine_aarch = newline.split(':')[1].strip('\n')
                            # print(Machine_aarch)
                        elif "CPU(s):" in line:
                            newline = re.sub(' +', ' ', line)
                            numberOfCpus = newline.split(':')[1].strip('\n')
                            # print(numberOfCpus)
            except:
                pass
            runcmd_file_path = results_file_1.split('/')
            runcmd_file = runcmd_file_path[len(runcmd_file_path) - 1]
            # runcmd_file =  path_level1 + 'runcmd.txt'
            if (os.path.exists(runcmd_file)):
                with open(runcmd_file) as f:
                    for line in f:
                        cfg_file = line.split("-c")[1].split()[0]
                        cfg_file = path_level2 + cfg_file
                        if (os.path.exists(cfg_file)):
                            with open(cfg_file) as f:
                                for line in f:
                                    if "ext           =" in line:
                                        flags = line.split("ext           =")[1]
                                        flags = flags.strip('\t+').rstrip()
                                        # print(flags)

                                        # else:
                                        #     print('NA')
            freq_file = path_level2 + 'mhz.log'
            if os.path.exists(freq_file):
                with open(freq_file) as f:
                    for line in f:
                        freq = line.split(",")[0]
                        # print(freq)
            if os.path.exists('results.csv') == 0:
                with open('results.csv', 'a') as f:
                    f.write("Machinename,Architecture,Kernel,DDRMemTotal,Numthreads,core_freq,Copies,flags,")
                    for g in csv_dictionary['Benchmark']:
                        f.write(g)
                        f.write(',')
                    f.write("FolderName")
                    f.write(',')
                    f.write("\n")
            with open('results.csv', 'a') as f:
                try:
                    BaseCopies = str(csv_dictionary['Base # Copies'][0])
                except:
                    BaseCopies = ' '
                    pass
                string2write = str(Machine_name) + ',' + str(
                    Machine_aarch) + KernelVersion + ',' + DDRMemTotal + ',' + str(numberOfCpus) + ',' + str(
                    freq) + ',' + BaseCopies + ',' + flags + ','
                f.write(str(string2write))
                try:
                    # if csv_dictionary['Base Status'] == 'S':
                    for g in csv_dictionary['Est. Base Rate']:
                        f.write(str(g))
                        f.write(',')
                    f.write(results_file_1)
                    f.write(',')
                    f.write("\n")
                except FileNotFoundError:
                    f.write(',,,,,,,,,,,,,')
                    f.write('\n')
                    pass
                    # print(csv_dictionary)
    except FileExistsError:
        print("No such file")
        pass


def csv2dictionary(csvlist):
    reader = csv.DictReader(csvlist)
    result = {}
    for row in reader:
        for column, value in row.items():
            result.setdefault(column, []).append(value)
    return result


def nth_root(val, n):
    ret = int(val ** (1. / n))
    return ret + 1 if (ret + 1) ** n == val else ret


for root, dirs_list, files_list in os.walk(path):
    for file_name in files_list:
        if os.path.splitext(file_name)[-1] == extension:
            prog = re.compile('CFP2006.*.csv')
            if prog.match(file_name):
                print(file_name)
                file_name_path = os.path.join(root, file_name)
                do_useful_stuff(file_name_path, file_name_path)
            else:
                pass
            # else:
            #     print("Should not come here")
