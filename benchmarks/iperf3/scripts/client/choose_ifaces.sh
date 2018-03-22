#!/usr/bin/env bash
# $1 = desired NIC speed
# $2 = output file destination
# $3 = name of machine
TYPE=$1
OUTPUT_DIR=$2
NAME=$3

# Get list of interfaces
iface_list=""
interfaces=$(ip link | grep "^[0-9]:" | awk -F ': ' '{print $2}' | awk -F '@' '{print $1}')
while read -r line; do
    ip="$(ifconfig | grep -A1 -P "$line[:| ]+" | tail -n1 \
        | grep -oP "[0-9]+.[0-9]+.[0-9]+.[0-9]+" | head -n1)"
    if [[ ! -z $ip ]]; then
        speed="$(ethtool $line 2>/dev/null | grep -i "speed:" \
            | awk -F ': ' '{print $2}' | awk -F 'b/s' '{print $1}' \
            | numfmt --from=si --to=si 2>/dev/null --format="%.0f")"
        if [[ ! -z $speed ]]; then
            iface_list="$iface_list$line/$ip/$speed\n"
        fi
    fi
done < <(echo "$interfaces")
ip="" && speed=""
echo "[$3] Listing interfaces..."
echo -e $iface_list

# Determine if there are matching interfaces
[[ "${TYPE}" == "50G" ]] && search_speed="25G" || search_speed="${TYPE}"
matching=$(echo -e $iface_list | grep $search_speed)
# No matching speed: use 10.7.56 interface (any speed)
if [[ -z $matching ]]; then
    echo "[$3] There are no $search_speed interfaces on this machine."
    first_ip10=$(echo -e "$iface_list" | grep 10.7.56 | head -n 1)
    iface=$(echo "$first_ip10" | awk -F '/' '{print $1}' | awk -F '.' '{print $1}')
    numa="$(cat /sys/class/net/$iface/device/numa_node)"    
    ip=$(echo $first_ip10 | awk -F '/' '{print $2}')
    speed=$(echo $first_ip10 | awk -F '/' '{print $3}')
    echo "[$3] Using first 10.7.56 interface ($first_ip10)."
else
    occurrences=$(echo "$matching" | wc -l)
    speed=${TYPE}
fi

# TEST IFACES
#matching="eth3.100/1.17.1.92/25G
#eth3/1.17.1.32/25G
#eth4/1.17.1.41.25G"
#occurrences=$(echo "$matching" | wc -l)

# Determine which interface(s) to use for test
# If there are multiple matches, follow priority
if [[ "$occurrences" -gt 1 ]]; then
    ip17=$(echo "$matching" | grep 1.17)
    ip18=$(echo "$matching" | grep 1.18)
    ip10=$(echo "$matching" | grep 10.7.56)
    # 50G: 1.17+1.18 > 1.17+1.17/1.18+1.18 > 1.17+10.7.56 > 10.7.56+10.7.56
    if [[ "$TYPE" == "50G" ]]; then
        # Case 1: both 1.17 and 1.18 present
        if [[ ! -z $ip17 ]] && [[ ! -z $ip18 ]]; then
            ip=$ip17
            ip2=$ip18
        # Case 2: only 10.7.56 present
        elif [[ -z $ip17 ]] && [[ -z $ip18 ]]; then
            ip=$ip10
            ip2=$(echo "$ip10" | sed 1d)
        # Case 3: two or more of 1.17 or 1.18
        elif [[ $(echo "$ip17" | wc -l) -gt 1 ]] || [[ $(echo "$ip18" | wc -l) -gt 1 ]]; then
            [[ -z $ip17 ]] && has_value="$ip18" || has_value="$ip17"
            ip=$has_value
            ip2=$(echo "$has_value" | sed 1d)
        # Case 4: only one 1.17 or 1.18, and 10.7.56
        else
            [[ -z $ip17 ]] && has_value="$ip18" || has_value="$ip17"
            ip=$has_value
            ip2=$ip10
        fi
        iface=$(echo "$ip" | head -n 1 | awk -F '/' '{print $1}' | awk -F '.' '{print $1}')
        iface2=$(echo "$ip2" | head -n 1 | awk -F '/' '{print $1}' | awk -F '.' '{print $1}')
        numa="$(cat /sys/class/net/$iface/device/numa_node)"
        numa2="$(cat /sys/class/net/$iface2/device/numa_node)"
        ip=$(echo "$ip" | head -n 1 | awk -F '/' '{print $2}')
        ip2=$(echo "$ip2" | head -n 1 | awk -F '/' '{print $2}')
        echo "[$3] Using ($ip)."
        [[ ! -z $ip2 ]] && echo "[$3] Using ($ip2)."
    # 1G/10G/25G/100G: 1.17 > 1.18 > 10.7.56 > 10.0.0
    else
        if [[ ! -z $ip17 ]]; then
            ip=$ip17
        elif [[ ! -z $ip18 ]]; then
            ip=$ip_18
        elif [[ ! -z $ip10 ]]; then
            ip=$ip_10
        else
            ip=$matching
        fi
        iface=$(echo "$ip" | head -n 1 | awk -F '/' '{print $1}' | awk -F '.' '{print $1}')
        numa="$(cat /sys/class/net/$iface/device/numa_node)"
        ip=$(echo "$ip" | head -n 1 | awk -F '/' '{print $2}')
        echo "[$3] More than one $speed interface found, using ($ip)."
    fi
# If there's only one match, obviously use that one
elif [[ "$occurrences" -eq 1 ]]; then
    [[ "$speed" == "50G" ]] && echo "[$3] Only one 25G interface available, switching to 25G test."
    iface=$(echo "$matching" | awk -F '/' '{print $1}' | awk -F '.' '{print $1}')
    numa="$(cat /sys/class/net/$iface/device/numa_node)"
    ip=$(echo "$matching" | awk -F '/' '{print $2}')
    echo "[$3] Using ($ip)."
fi

rm $OUTPUT_DIR/my_info 2>/dev/null
echo "ip=$ip" >> $OUTPUT_DIR/my_info
echo "ip2=$ip2" >> $OUTPUT_DIR/my_info
echo "numa=$numa" >> $OUTPUT_DIR/my_info
echo "numa2=$numa2" >> $OUTPUT_DIR/my_info
