#!/bin/bash
# version : 20201016
#  https://www.itread01.com/content/1524148852.html

if (($EUID != 0 )); then echo "Please run as root"; exit; fi


ten="          "
forty="$ten$ten$ten$ten"
eighty="$forty$forty"
#
format()
{
    # arg1: $1 msg to be format
    msg="$1"
    # arg2: $2 max length
    iMax="$2"
    if [ "${iMax}" = "" ]; then
        iMax=120
    fi
    #y="│${msg:0:${iMax}}${eighty:0:$((${iMax} - ${#msg}))}│"
    y="│${msg:0:${#msg}}${eighty:0:$((${iMax} - ${#msg}))}│"
    echo -e "${y}"
}

# config ############################
source IPSec.conf

# FORWARD
set_FORWARD() {
    # cat  /etc/sysctl.conf |grep ip_forward
    # cat  /proc/sys/net/ipv4/ip_forward
    sysctl -w net.ipv4.ip_forward=1
    # cat  /proc/sys/net/ipv4/conf/all/proxy_arp
    # echo 1 >  /proc/sys/net/ipv4/conf/all/proxy_arp
    sysctl -w net.ipv4.conf.all.proxy_arp=1

    cat  /proc/sys/net/ipv4/conf/default/rp_filter
    cat  /proc/sys/net/ipv4/conf/all/send_redirects
    cat  /proc/sys/net/ipv4/conf/all/accept_redirects
    cat  /proc/sys/net/ipv4/conf/default/send_redirects
    cat  /proc/sys/net/ipv4/conf/default/accept_redirects
    # let sysctl take effect immedially
    # only modify /etc/sysctl.conf require following to take effect immedially
    # sysctl -p /etc/sysctl.conf
}

# NE230 v1.0.5 require
# rgdb -s /InternetGatewayDevice/Layer3Forwarding/DefaultConnectionService "InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANIPConnection.1."
# rgdb -g /InternetGatewayDevice/Layer3Forwarding/DefaultConnectionService
# cat /var/run/ipsec_start.sh
# cat /var/setkey.conf

# stop racoon
stop() {
    echo "stop racoon"
    killall -9 racoon 2>/dev/null
    # /etc/init.d/racoon stop
    # racoon=$(ps aux|grep -v "^grep" |grep "racoon")
    # rc=$(awk -F" "  '{print $2}' <<< "$racoon")
    # echo "racoon ${rc}"

    echo "clear setkey"
    setkey -FP

    echo "clear iptables"
    iptables -F
    iptables -F -t nat

    if [ -e "${LOG_FILE}" ]; then
        rm "${LOG_FILE}"
    fi
}

add_route(){
    echo  "add WAN IP"
    echo "  ip addr add ${IPSEC_WAN_IP} dev ${IPSEC_WAN} 2> /dev/null"
    ip addr add ${IPSEC_WAN_IP} dev ${IPSEC_WAN} 2> /dev/null
    echo "add route"
    echo "   ip addr add ${IPSEC_LAN_IP} dev ${IPSEC_LAN} 2> /dev/null "
    ip addr add ${IPSEC_LAN_IP} dev ${IPSEC_LAN} 2> /dev/null
    # IPSec GW route?
    echo "   route add -net ${DUT_LAN_NET} gw ${IPSEC_LAN_IP} 2> /dev/null "
    route add -net ${DUT_LAN_NET} gw ${IPSEC_LAN_IP} 2> /dev/null

    # iptables
    echo "iptables -F"
    iptables -F
    echo "iptables -F -t nat"
    iptables -F -t nat
    echo "iptables -I INPUT -i ${IPSEC_WAN} --src ${DUT_WAN_IP} -j ACCEPT"
    iptables -I INPUT -i ${IPSEC_WAN} --src ${DUT_WAN_IP} -j ACCEPT
    echo "iptables -t nat -I PREROUTING -i  ${IPSEC_WAN} --src ${DUT_WAN_IP} --dst ${IPSEC_WAN_IP} -j ACCEPT"
    iptables -t nat -I PREROUTING -i  ${IPSEC_WAN} --src ${DUT_WAN_IP} --dst ${IPSEC_WAN_IP} -j ACCEPT
    echo "iptables -t nat -I POSTROUTING -o  ${IPSEC_WAN} --src ${IPSEC_LAN_NET} --dst ${DUT_LAN_NET} -j ACCEPT"
    iptables -t nat -I POSTROUTING -o  ${IPSEC_WAN} --src ${IPSEC_LAN_NET} --dst ${DUT_LAN_NET} -j ACCEPT
    echo "iptables -t nat -I PREROUTING -i  ${IPSEC_WAN} -p udp --dport ${UDP_PORT} -j ACCEPT"
    iptables -t nat -I PREROUTING -i  ${IPSEC_WAN} -p udp --dport ${UDP_PORT} -j ACCEPT

    #iptables -t nat -I POSTROUTING   ! -s 192.168.3.12/32  -o eth1 -j MASQUERADE
#-A POSTROUTING ! -s 192.168.3.158/32 -o eth4 -j MASQUERADE
    # www
    #  sudo route add default gw 192.168.70.1 dev eth2
    # route del default gw 192.168.70.1
    # sudo route del default gw 192.168.70.1 dev eth2
    # route del default gw 192.168.3.1

}

set_psk(){
    echo "set Pre-share key"
    # edit /etc/racoon/psk.txt
    # correct DUT WAN IP
    echo 'sed "s/DUT_WAN_IP/$DUT_WAN_IP/g" ./etc/racoon/psk.txt >  /etc/racoon/psk.txt'
    sed "s/DUT_WAN_IP/$DUT_WAN_IP/g" ./etc/racoon/psk.txt >  /etc/racoon/psk.txt
}

set_setkey(){
    echo "set setkey"
    # edit /etc/racoon/setkey.conf
    # correct DUT WAN IP
    echo 'sed -e "s|IPSEC_LAN_NET|$IPSEC_LAN_NET|g" \
    -e "s|DUT_LAN_NET|$DUT_LAN_NET|g" \
    -e "s/IPSEC_WAN_IP/$IPSEC_WAN_IP/g" \
    -e "s/DUT_WAN_IP/$DUT_WAN_IP/g" \
    -e "s/IPSEC_PROTOCAL/$IPSEC_PROTOCAL/g" \
    -e "s/IPSEC_MODE/$IPSEC_MODE/g"  ./etc/racoon/setkey.conf >  /etc/racoon/setkey.conf'
    sed -e "s|IPSEC_LAN_NET|$IPSEC_LAN_NET|g" \
    -e "s|DUT_LAN_NET|$DUT_LAN_NET|g" \
    -e "s/IPSEC_WAN_IP/$IPSEC_WAN_IP/g" \
    -e "s/DUT_WAN_IP/$DUT_WAN_IP/g" \
    -e "s/IPSEC_PROTOCAL/$IPSEC_PROTOCAL/g" \
    -e "s/IPSEC_MODE/$IPSEC_MODE/g" ./etc/racoon/setkey.conf >  /etc/racoon/setkey.conf
    # load setkey
    # /etc/init.d/setkey restart
    setkey -f  /etc/racoon/setkey.conf
    #### see SDP
    # setkey -DP
    ### see SDA
    #  setkey -D
}

set_racoon() {
    echo "set racoon"
    # edit /etc/racoon/racoon.conf
    # correct remote DUT WAN IP
    echo 'sed -e "s/DUT_WAN_IP/$DUT_WAN_IP/g" \
    -e "s|IPSEC_LAN_NET|$IPSEC_LAN_NET|g" \
    -e "s|DUT_LAN_NET|$DUT_LAN_NET|g" ./etc/racoon/racoon.conf > /etc/racoon/racoon.conf'
     sed -e "s/DUT_WAN_IP/$DUT_WAN_IP/g" \
    -e "s|IPSEC_LAN_NET|$IPSEC_LAN_NET|g" \
    -e "s|DUT_LAN_NET|$DUT_LAN_NET|g" ./etc/racoon/racoon.conf > /etc/racoon/racoon.conf
}

start_racoon(){
    echo "start racoon"
    if [ ! -e "/var/run/racoon/" ]; then
	mkdir -p /var/run/racoon/
    fi
    # /etc/init.d/racoon start
    racoon  -f /etc/racoon/racoon.conf -l "${LOG_FILE}" &
    # racoon -ddddddd -f /etc/racoon/racoon.conf -l /tmp/ipsec-log.txt -v
    tail -f  /tmp/ipsec-log.txt
}

status() {
    racoon=$(ps aux|grep -v "grep" |grep "racoon")
    if [ "$racoon" == "" ]; then
        echo "IPSec racoon is not running"
    else
        # 1. from DUT LAN PC ping IPSec server LAN
        # 2. sniffer IPSec GW's interface eth1 (IPSEC_WAN) should have ESP package (ISAKMP)
        echo "┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
        echo "│== topology ============================================================================================================│"
        format " PC1($IPSEC_LAN_PC)---($IPSEC_LAN_IP)IPSec($IPSEC_WAN_IP)---($DUT_WAN_IP)DUT($DUT_LAN_IP)---($DUT_LAN_PC)PC2"
        echo "│== config ==============================================================================================================│"
        format " DUT: "
        format "  Tunnel Mode: $IPSEC_PROTOCAL"
        format "  Remote IPSec Gateway Address:  $IPSEC_WAN_IP"
        format "  Local IP Address/subnet: $DUT_LAN_IP"
        format "  Remote IP Address: $IPSEC_LAN_IP"
        format "  Key Exchange Method : $KEY_EXCHANGE_METHOD"
        format "  Pre-Shared Key: "
        echo "│== setkey ==============================================================================================================│"
        format " show IPsec SA/SP database by following cmd:"
        format "  sudo setkey -DP  "
        #setkey -DP | while read line ; do
        #   format "   $line"
        #done
        #format "$sasp_db"
        echo "│== CHECK ===============================================================================================================│"
        format "  Ping require sometime to take effect!!"
        format "    PC1 can ping $DUT_LAN_PC          "
        format "    PC2 can ping $IPSEC_LAN_PC        "
        format "    sniffer package between IPSec and DUT's WAN can get '$IPSEC_PROTOCAL' package when pingng (ISAKMP)     "
        echo "│== log ===============================================================================================================│"
        cat ${LOG_FILE}
        echo "└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
    fi
}

start(){
    add_route
    set_psk
    set_setkey
    set_racoon
    start_racoon
}

case "$1" in
    'start')
            start
            ;;
    'stop')
            stop
            ;;
    'restart')
            stop ; echo "Sleeping..."; sleep 1 ;
            start
            ;;
    'status')
            status
            ;;
    *)
            echo
            echo "Usage: $0 { start | stop | restart | status }"
            echo
            exit 1
            ;;
esac

exit 0
