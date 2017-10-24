#!/usr/bin/python3
""""
Project Name : Cavium_BMTool
File Name: create_download_summary
Author: rgadgil
File Created: 09/20/2016   09:18
Details:
"""

import os

# os.system("rm -f /opt/logs/Nginx/*/summary_download.csv")
path = "/opt/logs/Nginx/"
for root, dirs, files in os.walk(path):
    for name in files:
        name1 = root + "/index.txt"
        if name == "index.txt":
            # print(name1)
            # for i, line in enumerate(fp):
            #    if i == 1:
            write_file_path = path + "/summary_download.csv"
            # print(write_file_path)
            # with open(write_file_path, "a+") as f1:
            try:
                f1 = open(write_file_path, 'a+')
                fp = open(name1)
                # fp.readline()
                things_to_write = fp.readline()
                f1.writelines(things_to_write.strip())
                f1.writelines(",")
                fp.close()
                try:
                    path1 = root + "/client0/values.txt"
                    print(path1)
                    # fextra = open(path1)
                    # things_to_again_write = fextra.readline().strip()
                    # f1.writelines(things_to_again_write)
                    # f1.writelines(",")
                    # fextra.close()
                    try:
                        path2 = root + "/SERVER_STATS/lsb_release.txt"
                        # print(path2)
                        flsb = open(path2)
                        flsb.readline()
                        flsb.readline()
                        read_here = flsb.readline().strip()
                        f1.writelines(read_here[20:])
                        f1.writelines(",")
                        flsb.close()
                        try:
                            path3 = root + "/SERVER_STATS/uname.txt"
                            funame = open(path3)
                            read_here1 = funame.readline().strip()
                            # print(read_here1)
                            f1.writelines(read_here1.split()[2])
                            f1.writelines(",")
                            funame.close()
                            path4 = root + "/client0/cmdline.txt"
                            funame = open(path4)
                            mystring = funame.read()
                            f1.writelines(mystring.split("10443/", 1)[1].split()[0])
                            # f1.writelines(",")
                            # f1.writelines(mystring.split("-V",1)[1].split()[0])
                            # f1.writelines(",")
                            # f1.writelines(mystring.split("-d",1)[1].split()[0])
                            f1.writelines(",")
                            funame.close()
                            path5 = root + "/SERVER_STATS/nginx.conf"
                            with open(path5, 'r') as verFile:
                                for line in verFile:
                                    if line.startswith("sendfile"):
                                        f1.writelines(line)
                        except:
                            pass
                    except:
                        pass
                except:
                    pass
            except:
                break
