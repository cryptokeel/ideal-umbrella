#!/bin/bash
#
#Author:  cryptokeel
#Created:  April 29, 2018
#
#  Set an IP for a interface set up statically, as well as auto initalize mac address (native to NIC)
#  used when cloning VMs that are set up statically.  Only does the IPADDR and HWADDR fields.  



if [[ $EUID -ne 0 ]]; then
   echo "You must be root to run this script." 
   exit 1
fi


RED='\033[0;31m'
BLUE='\033[1;34m'
PURP='\033[1;35m'
GREEN='\033[1;32m'
NC='\033[0m' # None

var1=( $(ls /etc/sysconfig/network-scripts | grep -v "lo" | grep ifcfg- | cut -c7-50) )
var2=( $(ip -o link  | awk '{print $2,$(NF-2)}' | awk '{print$1}' | sed 's/:$//') )

#Compares the two arrays above, prints out matches (where int exists and  ifcfg-x' file is created)
options=( $(echo ${var1[@]} ${var2[@]} | tr ' ' '\n' | sort | uniq -D | uniq) )

#Menu which uses values from "options" ^^ as selections, retrieves selected MAC for chosen for chosen interface
menu() {
    echo -e "${PURP}Set static IP & initalize MAC address for interface (requires 'ifcfg-' file in /etc/sysconfig/network-scripts)${NC}"
    for i in ${!options[@]}; do 
        printf "${BLUE}%3d%s) %s\n${NC}" $((i+1)) "${choices[i]:- }" "${options[i]}"
    done
}

prompt="Select your interface (Ctrl-c to exit): "
while menu && read -rp "$prompt" num && [[ "$num" ]]; do
    [[ "$num" != *[![:digit:]]* ]] &&
    (( num > 0 && num <= ${#options[@]} )) ||
    { warn="Invalid selection: $num"; echo -e "${RED}$warn${NC}" && break; }
    ((num--)); msg=$(ip -o link  | awk '{print $2,$(NF-2)}' | grep ^${options[num]} | awk '{print$2}')
    [[ "${choices[num]}" ]] && choices[num]=""
#Takes selection and puts it into the 'grep' command, spits out error and exits if selection dosen't exist

loc=/etc/sysconfig/network-scripts/ifcfg-${options[num]}

read -p "Enter a static IP: " ip
counti=$(grep -c -E 'IPADDR' $loc )

if [[ $counti -ge "2" ]];
then
	#Removes all duplicates and creates new one
	sed -i '/IPADDR.*/d' $loc
	echo "IPADDR="\""$ip"\""" >> $loc

elif [[ $counti -eq "1" ]];
then
	#Only one, so will replace exisiting and save it.
	sed -i 's/IPADDR=.*/IPADDR="'$ip'"'/ $loc

else
	#No paramater in the file, will append new one.
	echo "IPADDR="\""$ip"\""" >> $loc
fi


countl=$(grep -c -E 'HWADDR' $loc )

if [[ $countl -ge "2" ]];
then
        #Removes all duplicates and creates new one
        sed -i '/HWADDR.*/d' $loc
        echo "HWADDR="\""$msg"\""" >> $loc
	echo "Set MAC address... Done!"	

elif [[ $countl -eq "1" ]];
then
        #Only one, so will replace exisiting and save it.
        sed -i 's/HWADDR=.*/HWADDR="'$msg'"'/ $loc
	echo "Set MAC address... Done!"

else
        #No paramater in the file, will append new one.
        echo "HWADDR="\""$msg"\""" >> $loc
	echo "Set MAC address... Done!"

fi

ifdown ${options[num]} >/dev/null
ifup ${options[num]} >/dev/null

break

done
