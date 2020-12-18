#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or sudo" 
   exit 1
fi

source 00_setting

#restore setting
sudo killall -9 aftr 1>/dev/null 2>&1
sudo service isc-dhcp6-server stop
sudo service radvd stop
sudo service bind9 stop
#if [ "$isOldUbuntu" == "1" ]; then
#sudo service networking stop
#else
#if [ "$isRemote" == "0" ]; then
#sudo ifdown ${AFTR_WAN_IF}
#fi
#sudo ifdown ${AFTR_LAN_IF}
#fi

sudo cp  etc/network/interfaces.bak  /etc/network/interfaces

#sudo ifup ${AFTR_WAN_IF}
#sudo ifup ${AFTR_LAN_IF}

##if [ "$isOldUbuntu" == "1" ]; then
sudo service network-manager restart 
#sudo service networking restart
##else
#if [ "$isRemote" == "0" ]; then
#sudo ifup ${AFTR_WAN_IF}
#fi
#sudo ifup ${AFTR_LAN_IF}
#fi
