#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

hash parted 2>/dev/null || ( echo "parted not installed, installing..." && apt-get install parted )

if [ $# -le 2 ] ; then
        echo "To assign ownership of folder to a user, give the username."
        USER=`whoami`
else
        USER=$2
fi

if [ $# -le 1 ] ; then
        echo "Disk arg can be supplied in the form of link from /dev, e.g. sdd, will proceed with preparing all disks without GPT"
        TODO=`sudo parted -l 2>&1 | grep Error | cut -d ':' -f 2`
else
        TODO=$1
fi

echo -e "Prepping disks \n$TODO\n. Continue? (y/n)"
if [ -z "$FORCE" ] ; then
        read -d'' -s -n 1
        if [ "$REPLY" != "y" ] ; then
                echo "Quitting"
                exit 1
        fi
else
        FORCE_parted=-s
        FORCE_mkfs=-F
fi
echo "  Starting operation."

DISKNAMES=`echo $TODO | sed -e "s/\/dev\///g"`

for disk in $DISKNAMES ; do
        #first unmount and remove from fstab if there
        mount | grep -q ${disk}1 && echo "- unmounting..." && umount /dev/${disk}1
        grep ${disk} /etc/fstab > /dev/null && \
        grep -v ${disk} /etc/fstab > fstab.tmp && \
        cp fstab.tmp /etc/fstab

        #then create partition
        CMD="parted $FORCE_parted /dev/$disk mklabel gpt"
        echo "- $CMD" && $CMD
        CMD="parted $FORCE_parted /dev/$disk mkpart primary ext4 1% 100%"
        echo "- $CMD" && $CMD
        sync
        sleep 1
        mount | grep -q ${disk}1 && echo "- unmounting..." && umount /dev/${disk}1
        #file system
        CMD="mkfs $FORCE_mkfs -t ext4 /dev/${disk}1"
        echo "- $CMD" && $CMD
        value=`cat /sys/block/$disk/queue/rotational`
        if [ $value == 1 ];
        then
                type="hdd"
        else
                type="ssd"
        fi
        i=0
        unset found
        links=`lsblk | grep $type | sed -e "s/.*$type/$type/" -e "s/$/X/"`
        while [ -z "$found" ] ; do
                i=$[ $i + 1 ]
                if [[ "$links" =~ "${type}${i}X" ]] ; then
                        continue
                else
                        found=1
                        break
                fi
        done
        mount_point=/mnt/${type}$i
        echo "mounting at $mount_point"
        mkdir -p $mount_point
        #setup new fstab entry and mount, remove prev fstab entry if any
        grep $mount_point /etc/fstab > /dev/null && \
        grep -v $mount_point /etc/fstab > fstab.tmp && \
        cp fstab.tmp /etc/fstab

        sync
        sleep 1
        uuid=`lsblk -o UUID -n -l /dev/${disk}1 | grep -`
        echo "UUID=${uuid} $mount_point ext4 rw,user,noauto,exec 0 0" >> /etc/fstab
        mount $mount_point
        #create folders
        for D in hdfs tmp other ; do
                mkdir -p $mount_point/$D
                chmod a+wrx $mount_point/$D
                chown $USER:$USER $mount_point/$D
        done
done
