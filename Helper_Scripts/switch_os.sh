#!/usr/bin/env bash

helpmenu()
{
    cat <<__help_EOF
usage= $0 <GRUB_MENU_ENTRY>
where:
<GRUB_MENU_ENTRY>           Grub menu entry number shown in the list.

__help_EOF
echo -e
cat /boot/grub/grub.cfg | grep "menuentry "| awk 'BEGIN{FS="'"'"'"}{print $2}' | grep -n '[^[:blank:]]'
}


if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if (($# < 1))
then
    helpmenu; exit 1;
fi
OPTION_NUMBER=$1
OPTION_NUMBER_BOOT=$(( ${OPTION_NUMBER}-1 ))
echo "We will boot to"
cat /boot/grub/grub.cfg | grep "menuentry "| awk 'BEGIN{FS="'"'"'"}{print $2}' | grep -n '[^[:blank:]]' | head -n ${OPTION_NUMBER} | tail -1
echo -e "\nAre you sure you want to change default for next boot to another OS?\nHave you saved your work?.\nStill want to Continue? (y/n)"

read -d'' -s -n 1
if [ "$REPLY" != "y" ] ; then
        echo -e "\nGrub Update aborted"
        exit 1
else
        echo -e "i\nNow updating grub for next boot."
        grub-reboot ${OPTION_NUMBER_BOOT}
fi
