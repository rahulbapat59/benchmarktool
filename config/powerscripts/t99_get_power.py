#!/usr/bin/python3

""""
Project Name : Cavium_BMTool
File Name: t99_get_power  
Author: rgadgil 
File Created: 12/20/2016   15:06
Details:
"""


def substring_after(s, delimiter):
    return s.partition(delimiter)[2]


file = open('power.txt')
core_current_string = "Core Current = "
core_voltage_string = "Core VRM Voltage = "
mem_current_string = "Mem Current = "
mem_voltage_string = "Mem VRM Voltage = "
sram_current_string = "SRAM Current = "
sram_voltage_string = "SRAM VRM Voltage = "
soc_current_string = "SoC Current = "
soc_voltage_string = "SoC VRM Voltage = "

i = 0
for line in file:
    # print(i,line)
    if i == 4:
        core_current = substring_after(line, core_current_string)
        # print(core_current)
    elif i == 7:
        core_voltage = substring_after(line, core_voltage_string)
        # print(core_voltage)
    elif i == 8:
        mem_current = substring_after(line, mem_current_string)
        # print(mem_current)
    elif i == 11:
        mem_voltage = substring_after(line, mem_voltage_string)
        # print(mem_voltage)
    elif i == 12:
        sram_current = substring_after(line, sram_current_string)
        # print(sram_current)
    elif i == 15:
        sram_voltage = substring_after(line, sram_voltage_string)
        # print(sram_voltage)
    elif i == 16:
        soc_current = substring_after(line, soc_current_string)
        # print(soc_current)
    elif i == 17:
        soc_voltage = substring_after(line, soc_voltage_string)
        # print(soc_voltage)
        break
    i += 1
power1 = float(core_current) * float(core_voltage)
power2 = float(mem_current) * float(mem_voltage)
power3 = float(sram_current) * float(sram_voltage)
power4 = float(soc_current) * float(soc_voltage)
total_core_power = power1 + power2 + power3 + power4
total_core_power /= 1000.0
print(str(format(total_core_power, '.2f')) + " W")
