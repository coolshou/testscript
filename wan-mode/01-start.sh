#!/bin/bash

#set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or sudo" 
   exit 1
fi

function isRunning {
    #check service is running
    name=$1
    #r=`service ${name} status`
    echo "TODO: check service ${name} status"
}

source 00_setting

echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

#kill all service
echo "###### kill all service ###### "
sudo service strongswan stop
sudo service xl2tpd stop
sudo service accel-ppp stop
sudo killall -9 aftr 1>/dev/null 2>&1
sudo service isc-dhcp6-server stop
sudo killall -9 dhcpd 1>/dev/null 2>&1
sudo service radvd stop
sudo service bind9 stop
sudo service isc-dhcp-server stop

if [ "$isOldUbuntu" == "1" ]; then
	#ununtu 14.04 not support this way!!
	echo "###### networking stop ###### "
	sudo service networking stop
else
	echo "###### ${AFTR_WAN_IF} down ###### "
	sudo ifdown ${AFTR_WAN_IF} &> /dev/null
	echo "###### ${AFTR_LAN_IF} down ###### "
	sudo ifdown ${AFTR_LAN_IF} &> /dev/null
fi

echo "###### update network config ###### "
sed -e "s/#AFTR_WAN_IF#/${AFTR_WAN_IF}/g" \
		-e "s/#AFTR_LAN_IF#/${AFTR_LAN_IF}/g" \
		-e "s/#AFTR_LAN_IPv6#/${AFTR_LAN_IPv6}/g" \
		-e "s/#LAN_IP#/${LAN_IP}/g" \
		-e "s/#AFTR_WAN_IP#/${AFTR_WAN_IP}/g" \
		-e "s/#AFTR_WAN_GW#/${AFTR_WAN_GW}/g" \
		-e "s/#AFTR_WAN_IPv6#/${AFTR_WAN_IPv6}/g" \
		-e "s/#MANAGER_IF#/${MANAGER_IF}/g" \
		-e "s/#MANAGER_IP#/${MANAGER_IP}/g" \
		-e "s/#DNS_IP#/${DNS_IP}/g" \
		-e "s/#GW_IP#/${GW_IP}/g" \
		etc/network/interfaces | sudo tee /etc/network/interfaces > /dev/null
echo "###### network-manager restart ###### "
sudo service network-manager restart #do not let network namager control ethX
#network
echo "###### networking restart ###### "
sudo service networking restart



echo "###### ${AFTR_WAN_IF} up ###### "
sudo ifup ${AFTR_WAN_IF} &> /dev/null
echo "###### ${AFTR_LAN_IF} up ###### "
sudo ifup ${AFTR_LAN_IF} &> /dev/null

	echo "###### bind9 (DNS) ###### "
	sudo cp etc/bind/named.conf /etc/bind/
	sudo cp etc/bind/named.conf.example-zones /etc/bind/
	sudo cp etc/bind/named.conf.logging /etc/bind/
	sudo cp etc/bind/named.conf.options /etc/bind/
	#sudo cp etc/bind/named.aftr /etc/bind/
	sed -e "s/#AFTR_WAN_IP#/${AFTR_WAN_IP}/g" \
		-e "s/#AFTR_WAN_GW#/${AFTR_WAN_GW}/g" \
		-e "s/#AFTR_ENDPOINT_IPv6#/${AFTR_ENDPOINT_IPv6}/g" \
		-e "s/#AFTR_WAN_IPv6#/${AFTR_WAN_IPv6}/g" \
		etc/bind/named.aftr | sudo tee /etc/bind/named.aftr > /dev/null
	#sudo cp bind/named.example /etc/bind/
	sudo service bind9 restart

	echo "###### radvd ###### "
	if [ ${IPV6MODE} == 0 ]; then
		Mflag=off
		Oflag=off
	elif [ ${IPV6MODE} == 1 ]; then
		Mflag=off
		Oflag=on
	elif [ ${IPV6MODE} == 2 ]; then
		Mflag=on
		Oflag=on
	else
		echo "Wrong IPV6MODE(${IPV6MODE}) setting"
		exit 2
	fi
	sed -e "s/#AFTR_LAN_IF#/${AFTR_LAN_IF}/g" \
		-e "s/#AFTR_ACL6#/${AFTR_ACL6}/g" \
		-e "s/#Mflag#/${Mflag}/g" \
		-e "s/#Oflag#/${Oflag}/g" \
		etc/radvd.conf | sudo tee /etc/radvd.conf > /dev/null

	#sudo cp radvd.conf /etc/
	sudo service radvd start

	#dhcpv6
	if [ ${IPV6MODE} -ge 1 ]; then
		echo "###### dhcpv6 ###### "

		sed -e "s/#DHCP6_IF#/${DHCP6_IF}/g" \
			etc/dhcp/default/isc-dhcp6-server | sudo tee /etc/default/isc-dhcp6-server > /dev/null

		# dhcp/isc-dhcp6-server
		sudo cp etc/dhcp/isc-dhcp6-server /etc/init.d/isc-dhcp6-server
		sudo systemctl daemon-reload

		if [ ! -e /var/db/dhcpd6.leases ]; then
			if [ ! -e /var/db/ ]; then
				sudo mkdir /var/db/
			fi
			sudo touch /var/db/dhcpd6.leases
		fi
		if  [ ! -e /var/lib/dhcp/dhcpd6.leases ]; then
			if [ ! -e /var/lib/dhcp/ ]; then
				sudo mkdir /var/lib/dhcp/
			fi
			sudo touch /var/lib/dhcp/dhcpd6.leases
		fi

		sed -e "s/#DUT_WAN_MAC#/${DUT_WAN_MAC}/g" \
			-e "s/#AFTR_LAN_IPv6#/${AFTR_LAN_IPv6}/g" \
			-e "s/#DNS_IPv6_2#/${DNS_IPv6_2}/g" \
			-e "s/#ROUTER_IPv6#/${ROUTER_IPv6}/g" \
			-e "s/#ROUTE_IPv6_PREFIX#/${ROUTE_IPv6_PREFIX}/g" \
			-e "s/#AFTR_ACL6#/${AFTR_ACL6}/g" \
			-e "s/#DHCPv6_IPv6_START#/${DHCPv6_IPv6_START}/g" \
			-e "s/#DHCPv6_IPv6_END#/${DHCPv6_IPv6_END}/g" \
			-e "s/#DUT_WAN2_MAC#/${DUT_WAN2_MAC}/g" \
			-e "s/#ROUTER2_IPv6#/${ROUTER2_IPv6}/g" \
			etc/dhcp/aftr-dhcpd6.conf | sudo tee /etc/dhcp/aftr-dhcpd6.conf > /dev/null
		#dhcpd -d -6 -cf dhcp/aftr-dhcpd6.conf eth1
		#dhcpd -d -f
		sudo service isc-dhcp6-server start
		if [ ! -e /etc/aftr ]; then
			mkdir /etc/aftr/
		fi
	fi
if [ ${DS_LITE} == 1 ]; then
	echo "###### aftr ###### "
	#config aftr.conf
	sed -e "s/#AFTR_ICMP#/${AFTR_ICMP}/g" \
		-e "s/#AFTR_ENDPOINT_IPv6#/${AFTR_ENDPOINT_IPv6}/g" \
		-e "s/#AFTR_ACL6#/${AFTR_ACL6}/g" \
		etc/aftr/aftr.conf | sudo tee /etc/aftr/aftr.conf > /dev/null
	#config aftr-script
	# TODO: multi DS-Lite DUT's IPv6 IP
	sed -e "s/#AFTR_WAN_IF#/${AFTR_WAN_IF}/g" \
		-e "s/#AFTR_ICMP#/${AFTR_ICMP}/g" \
		-e "s/#AFTR_WAN_MAC#/${AFTR_WAN_MAC}/g" \
		-e "s/#B4_TUNNEL_IP#/${B4_TUNNEL_IP}/g" \
		-e "s/#AFTR_ENDPOINT_IPv6_PREFIX#/${AFTR_ENDPOINT_IPv6_PREFIX}/g" \
		-e "s/#ROUTE_IPv6_PREFIX#/${ROUTE_IPv6_PREFIX}/g" \
		-e "s/#ROUTER_IPv6#/${ROUTER_IPv6}/g" \
		-e "s/#ROUTER2_IPv6#/${ROUTER2_IPv6}/g" \
		etc/aftr/aftr-script | sudo tee /etc/aftr/aftr-script > /dev/null
	chmod +x /etc/aftr/aftr-script
	#require once?
	#if [ ! -e "/etc/modules-load.d/aftr-module.conf" ]; then
	#	sudo cp aftr/aftr-module.conf /etc/modules-load.d/
	#fi
	sudo aftr -c /etc/aftr/aftr.conf -s /etc/aftr/aftr-script &> /var/log/aftr.log
else
	echo "###### ip v6 default route setting clear"
	echo "ip -6 route del default"
	ip -6 route del default
#	echo "ip -6 route del ${ROUTE_IPv6_PREFIX}/64 dev ${AFTR_LAN_IF}"
#	ip -6 route del ${ROUTE_IPv6_PREFIX}/64 dev ${AFTR_LAN_IF}

        echo "###### ip v6 default route setting "
	echo "ip -6 route add ${ROUTE_IPv6_PREFIX}/64 via ${ROUTER_IPv6}"
	ip -6 route add ${ROUTE_IPv6_PREFIX}/64 via ${ROUTER_IPv6}
#	sleep 1
#	echo "ip -6 route add default via $DUT_WAN_LLA dev ${AFTR_LAN_IF}"
#	ip -6 route add default via $DUT_WAN_LLA dev ${AFTR_LAN_IF}

fi
if [ "${useIPSEC}" == "1" ]; then
	echo "#####IPSec"
	if [ ! -e /etc/ipsec.d/ ]; then
		mkdie /etc/ipsec.d/
	fi
	#cp etc/ipsec.d/ipsec.secrets /etc/ipsec.d/
	#/etc/ipsec.conf
	sudo service strongswan start
	sudo service xl2tpd start

else
if [ ${ACCEL_PPP} == 1 ]; then
	echo "############ Start pppoe/l2tp/pptp setting ############ "
	#pppoe/l2tp/pptp server
	echo "###### pppoe/l2tp/pptp server ###### "
	if [ "${USE_STATIC_IP}" == "1" ]; then
		ACCELPPP=accel-ppp-static.conf
	else
		ACCELPPP=accel-ppp.conf
	fi
	sed -e "s/#GW_IP#/${GW_IP}/g" \
		-e "s/#PPP_IP#/${PPP_IP}/g" \
		-e "s/#DNS_IP#/${DNS_IP}/g" \
		-e "s/#DNS_IP2#/${DNS_IP2}/g" \
		-e "s/#DNS_IP2#/${DNS_IP2}/g" \
		-e "s/#DNS_IPv6#/${DNS_IPv6}/g" \
		-e "s/#DNS_IPv6_2#/${DNS_IPv6_2}/g" \
		-e "s/#IPPOOL_PPPOE#/${IPPOOL_PPPOE}/g" \
		-e "s/#IPPOOL_PPTP#/${IPPOOL_PPTP}/g" \
		-e "s/#IPPOOL_L2TP#/${IPPOOL_L2TP}/g" \
                -e "s/#AFTR_LAN_IF#/${AFTR_LAN_IF}/g" \
		etc/${ACCELPPP} | sudo tee /etc/accel-ppp.conf > /dev/null

	sudo ln -sf /etc/accel-ppp.conf /etc/accel-ppp/accel-ppp.conf
	sed -e "s/#DHCP_IF#/${DHCP_IF}/g" \
		etc/accel-ppp/if-down | sudo tee /etc/accel-ppp/if-down > /dev/null
	#sudo cp etc/accel-ppp/if-down /etc/accel-ppp/if-down
	sed -e "s/#DHCP_IF#/${DHCP_IF}/g" \
		etc/accel-ppp/if-up | sudo tee /etc/accel-ppp/if-up > /dev/null
	#sudo cp etc/accel-ppp/if-up /etc/accel-ppp/if-up

	if [ "${USE_STATIC_IP}" == "1" ]; then
		sed -e "s/#IP_PPPOE#/${IP_PPPOE}/g" \
			-e "s/#IP_PPTP#/${IP_PPTP}/g" \
			-e "s/#IP_L2TP#/${IP_L2TP}/g" \
			etc/ppp/chap-secrets.static | sudo tee /etc/ppp/chap-secrets > /dev/null
	else
		sudo cp etc/ppp/chap-secrets /etc/ppp/chap-secrets
	fi

	sudo service accel-ppp start

fi
fi
#if [ ! ${DS_LITE} == 1 ]; then
	#dhcp v4
	echo "############ update dhcp v4 setting ############ "
	sed -e "s/#DHCP_IF#/${DHCP_IF}/g" \
		etc/dhcp/default/isc-dhcp-server | sudo tee /etc/default/isc-dhcp-server > /dev/null

	sed -e "s/#IPPOOL_DHCPv4_START#/${IPPOOL_DHCPv4_START}/g" \
		-e "s/#IPPOOL_DHCPv4_END#/${IPPOOL_DHCPv4_END}/g" \
		-e "s/#GW_IP#/${GW_IP}/g" \
		-e "s/#DHCPv4_DNS#/${DHCPv4_DNS}/g" \
		-e "s/#DHCPv4_DNS2#/${DHCPv4_DNS2}/g" \
		etc/dhcp/192.168.3.0.conf | sudo tee /etc/dhcp/192.168.3.0.conf > /dev/null
	sudo service isc-dhcp-server start
#fi
#update-motd.d/99-dslite
echo "############ /etc/update-motd.d/99-dslite info ############ "
cp etc/update-motd.d/99-dslite /etc/update-motd.d/99-dslite
source /etc/update-motd.d/99-dslite

#chmod 664 /etc/systemd/system/wan-mode.service
#systemctl daemon-reloa
#systemctl enable wan-mode.service
#systemctl start wan-mode.service

