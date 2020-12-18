#!/bin/bash
# version : 20201016
# ref:
#       https://www.systutorials.com/docs/linux/man/8-ip-l2tp/
# check root
if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi

## Value=0 -> Output to syslog, Value=1 -> Output to log file.
# TZ_LOG_OUTPUT_FLAG=0

DEBUG=1

ten="          "
forty="$ten$ten$ten$ten"
eighty="$forty$forty"

PKG_NAME=$(basename $0)
LOG_FILE=/tmp/${PKG_NAME}.log
PID_FILE=/var/run/${PKG_NAME}.pid

# Output the log to log file.
log()
{
    time="$(cat /proc/uptime)"
    if [ "${TZ_LOG_OUTPUT_FLAG}" = "1" ]; then
        echo "[   ${time}] [rootfs] $0: $@" >> ${LOG_FILE}
    else
        logger -t "$0: " -s $@ > /dev/null 2>&1
    fi
}
debug()
{
    time="$(cat /proc/uptime)"
    if [ "${DEBUG}" = "1" ]; then
        echo -e "[${time}]:$1"
    fi
}
#
format()
{
    # arg1: $1 msg to be format
    msg="$1"
    # arg2: $2 max length
    iMax="$2"
    if [ "${iMax}" = "" ]; then
        iMax=84
    fi
    #y="│${msg:0:${iMax}}${eighty:0:$((${iMax} - ${#msg}))}│"
    y="│${msg:0:${#msg}}${eighty:0:$((${iMax} - ${#msg}))}│"
    echo "${y}"
}
############################################
source l2tpv3.conf

setup_ip()
{
    debug "ip addr add ${local_ip_addr} broadcast ${local_bcast} dev ${local_if}"
    ip addr add ${local_ip} broadcast ${local_bcast} dev ${local_if}
    if [ "${bridge_enable}" = "1" ]; then
        debug "setup bridge..."
        out=$(brctl show  |grep ${bf_if})
        if [  "${out}" = "" ]; then
            debug "   ip link add ${bf_if} type bridge"
            ip link add ${bf_if} type bridge
        fi
        #debug "   ip link set ${bf_if} up mtu ${mtu} "
        #ip link set ${bf_if} up mtu ${mtu}  2>/dev/null

        if [ ${vlan_id} -gt 0 ]; then
            #debug "   ip r add ${LAN_Net} dev ${bf_if}  proto kernel  scope link  src  ${LAN_IP}"
            #ip r add ${LAN_Net} dev ${lan_if}  proto kernel  scope link  src  ${LAN_IP}
            debug "setup vlan..."
            debug "    ip link set ${session_if} up mtu ${mtu}"
            ip link set ${session_if} up  mtu ${mtu}
            debug "    ip link add link ${session_if} name ${session_if}.${vlan_id} type vlan id ${vlan_id}"
            ip link add link ${session_if} name ${session_if}.${vlan_id} type vlan id ${vlan_id}
            debug "    ip link set ${session_if}.${vlan_id} up mtu ${mtu} master ${bf_if}"
            ip link set ${session_if}.${vlan_id} up mtu ${mtu} master ${bf_if}
            debug "    ip link add link ${lan_if} name ${lan_if}.${vlan_id} type vlan id ${vlan_id}"
            ip link add link ${lan_if} name ${lan_if}.${vlan_id} type vlan id ${vlan_id}
            # add to bridge and bring up
            debug "    ip link set ${lan_if}.${vlan_id} up master ${bf_if}"
            ip link set ${lan_if}.${vlan_id} up master ${bf_if}
            debug "setup vlan ip: "
            debug "   ip addr add ${local_tun_ip} broadcast ${local_tun_brd} dev ${bf_if}"
            ip addr add ${local_tun_ip} broadcast ${local_tun_brd} dev  ${bf_if}
            debug "   ip link set ${bf_if} up"
            ip link set ${bf_if} up
            debug "setup route : "
            debug "    ip route add ${peer_tun_net} via ${local_tun_ip_addr} dev ${bf_if}  scope link"
            ip route add ${peer_tun_net} via ${local_tun_ip_addr} dev ${bf_if}  scope link
            ip route add ${local_tun_net} dev ${bf_if}

        else
            debug "   ip addr del   ${LAN_IP}/32 dev ${lan_if} 2>/dev/null"
            ip addr del   ${LAN_IP}/32 dev ${lan_if} 2>/dev/null
            debug "   ip addr add ${LAN_IP} broadcast ${LAN_BCAST} dev ${bf_if}"
            ip addr add ${LAN_IP}/24 broadcast ${LAN_BCAST}  dev ${bf_if}
            debug "   ip link set ${bf_if} up"
             ip link set ${bf_if} up
            #debug "   ip r add ${LAN_Net} dev ${bf_if}  proto kernel  scope link  src  ${LAN_IP}"
            #ip r add ${LAN_Net} dev ${bf_if}  proto kernel  scope link  src  ${LAN_IP}
            debug "   ip link set ${session_if} master ${bf_if}"
            ip link set ${session_if} master ${bf_if}
            debug "   ip link set ${lan_if} master ${bf_if}"
            ip link set ${lan_if} master ${bf_if}
            debug "setup route : "
            debug "   ip route add ${DUT_LAN_NET} via ${LAN_IP} scope link"
            ip route add ${DUT_LAN_NET} via ${LAN_IP} scope link

        fi
    else
        debug "   ip link set ${session_if} up mtu ${mtu} "
        ip link set ${session_if} up mtu ${mtu} 2>/dev/null
        debug "   ip route add ${peer_tun_net} via ${LAN_IP} scope link"
        ip route add ${peer_tun_net} via ${LAN_IP} scope link
    fi
    if [ ${DEBUG} = "1" ]; then
        out=$(route -n)
        debug "${out}"
    fi

}

del_ip(){
    echo "Do not remove wan IP ${local_ip_addr} on dev  ${local_if} "
    # debug "ip addr del ${local_ip_addr} broadcast ${local_bcast} dev ${local_if}"
    # ip addr del ${local_ip} broadcast ${local_bcast} dev ${local_if}

}
# L2TPv3 over IP
setup_tun_ip()
{
    ip l2tp add tunnel local ${local_ip} remote ${peer_ip} tunnel_id ${local_tun_id} peer_tunnel_id ${peer_tun_id} encap ip 2>/dev/null
    ip l2tp add session ${session_if} tunnel_id ${local_tun_id} session_id ${local_session_id} peer_session_id ${peer_session_id} 2>/dev/null
    setup_ip
    log "l2tpv3 ip protocol tunnel setup successful."
}
# L2TPv3 over UDP
setup_tun_udp()
{
    debug "set L2TPv3 over UDP tunnel"
    debug "   ip l2tp add tunnel local ${local_ip} remote ${peer_ip} tunnel_id ${local_tun_id} peer_tunnel_id ${peer_tun_id} udp_sport ${local_port} udp_dport ${peer_port} encap udp udp_csum ${udp_csum} "
    ip l2tp add tunnel local ${local_ip} remote ${peer_ip} tunnel_id ${local_tun_id} peer_tunnel_id ${peer_tun_id} udp_sport ${local_port} udp_dport ${peer_port} encap udp udp_csum ${udp_csum} 2>/dev/null
    debug "set L2TPv3 session"
    debug "   ip l2tp add session name ${session_if} tunnel_id ${local_tun_id} session_id ${local_session_id} peer_session_id ${peer_session_id} 2>/dev/null"
    ip l2tp add session name ${session_if} tunnel_id ${local_tun_id} session_id ${local_session_id} peer_session_id ${peer_session_id} 2>/dev/null
    setup_ip
    log "l2tpv3 udp protocol tunnel setup successful."
}

del_default_route()
{
    cur_def_route=$(ip route |grep default |grep ${session_if} )
    [ "${default_gw_enable}" = "1" -a "${cur_def_route}" != "" ] && {
        debug "    ip route del ${cur_def_route} 2>/dev/null"
        ip route del ${cur_def_route} 2>/dev/null
    }
}

setup_bridge()
{
    if [ "${bridge_enable}" = "1" ]; then
        if [ "${vlan_id}" = "1" ] || [ "${vlan_id}" -gt "0" ]; then
            # eth
            ip link set  ${session_if}.${vlan_id} up
            ip link set  ${lan_if}.${vlan_id} up
            ip link set  brvlan1 up
        else
            brctl addbr br0
            brctl addif br0 ${session_if} 2>/dev/null
        fi
    fi
}

del_bridge()
{
    if [ "${bridge_enable}" = "1" ]; then
        if [ ${vlan_id} -gt 0 ]; then
            debug "=====bring ${session_if}.${vlan_id} down"
            ip link set  ${session_if}.${vlan_id} down 2>/dev/null
            debug "=====bring ${lan_if}.${vlan_id} down"
            ip link set ${lan_if}.${vlan_id} down  2>/dev/null
            debug "=====delete ${lan_if}.${vlan_id} "
            ip link delete ${lan_if}.${vlan_id}   2>/dev/null
        fi
            debug "=====bring ${bf_if} down"
            ip link set ${bf_if} down  2>/dev/null
            debug "=====delete ${bf_if} "
            ip link delete ${bf_if} 2>/dev/null
            #debug "   ip addr add ${LAN_IP} dev ${lan_if}"
            #ip addr add ${LAN_IP} dev ${lan_if}
    else
        debug "=====bring ${session_if} down"
        ip link set ${session_if} down  2>/dev/null
        debug "=====delete ${session_if} "
        ip link delete ${session_if} 2>/dev/null
    fi
}

start_service()
{
    case ${protocol} in
        ip)
            setup_tun_ip
            ;;

        udp)
            setup_tun_udp
            ;;
    esac
    # setup_bridge
    # add_default_route
}

stop_service()
{
    ip l2tp del session tunnel_id ${local_tun_id} session_id ${local_session_id} 2>/dev/null
    ip l2tp del tunnel tunnel_id ${local_tun_id} 2>/dev/null
    del_default_route
    del_bridge
    del_ip
}

restart_service()
{
    stop_service
    start_service
}

query_status()
{
    echo "┌────────────────────────────────────────────────────────────────────────────────────┐"
    echo "│== topology ========================================================================│"
        format " PC1($local_PC)---($LAN_IP)L2TPv3($local_ip)---($peer_ip)DUT($DUT_LAN_IP)---($DUT_LAN_PC)PC2"
    if [ ${vlan_id} -gt 0 ]; then
        format "  | v10: $local_tun_pc    $local_tun_ip_addr                                             $peer_tun_ip_addr   $peer_tun_pc"
    fi
    format "    "
    echo "│==tunnel============================================================================│"
    format "    "
    ip l2tp show tunnel 2>/dev/null | \
        while IFS= read -r line ;   do
            format " ${line}"
        done
    format "    "
    echo "│==session===========================================================================│"
    format "    "
    ip l2tp show session 2>/dev/null | \
        while IFS= read -r line ;   do
            chrlen=${#line}
            if [ ${chrlen} -gt 0 ]; then
                format " ${line}"
            fi
        done
    format "    "
     if [ "$bridge_enable" = "1" ]; then
            format "    "
            echo "│==bridge setting====================================================================│"
            #out=$(brctl show)
            #brctl show | sed 1d |
            brctl show | \
            while IFS= read -r line ;   do
                #nline=$(echo  -e ${line} |  sed 's/[\t]/[[:space:]]/g')
                # count \t number
                #nline="${line//[!\t]}"
                #chrlen=${#line}
                #format "${chrlen}: ${line}"
                format " ${line}"
                # format "${chrlen}: ${nline}"
            done
            echo "│==route setting=====================================================================│"
            route -n 2>/dev/null | \
            while IFS= read -r line ;   do
                format " ${line}"
            done
        fi
        format "    "
    spd=$(ip l2tp show session)
    if [ "$spd"  != "" ]; then
        echo "│==DUT should set====================================================================│"
        format "    "
        format "   L2TPv3 Server IP Address=${local_ip}"
        format "   local tunnel id=${peer_tun_id}"
        format "   peer tunnel id=${local_tun_id}"
        if [ "${protocol}" = "udp" ]; then
            format "   local udp port(sport)=${peer_port}"
            format "   peer udp port(dport)=${local_port}"
        fi
        #if [ ${vlan_id} -gt 0 ]; then
        #   format "   local_ip=${peer_ip} , peer_ip=${local_ip}"
        #fi
        format "   local session id=${peer_session_id}"
        format "   peer session id=${local_session_id} "
        format "   mtu=${mtu}                "
        if [ ${vlan_id} -gt 0 ]; then
            format "   local vlan ip=${peer_tun_ip_addr}"
            format "   peer vlan ip=${local_tun_ip_addr}"
        else
            #format "   local_tun_ip=${peer_tun_ip}  ,  peer_tun_ip=${local_tun_ip}"
            format "   Peer LAN IP =${LAN_IP}"
        fi
        format "    "
        if [ ${vlan_id} -gt 0 ]; then
            echo "│==vlan setting======================================================================│"
            format "    "
            format "   vlan_id=${vlan_id} "
            format "    "
        fi
        echo "│== CHECK ===========================================================================│"
            format "     NOTICE: check PC1 and PC2's default gateway/route first!!'"
            format "          eg:"
            format "               PC1:  ip r add $peer_tun_net via $local_tun_pc"
            format "               PC2:  route add $local_tun_net $peer_tun_pc"
        if [ ${vlan_id} -gt 0 ]; then
                    format "     NOTICE2: PC's LAN should setup vlan id = ${vlan_id}"
            format "    "
            format "    1. DUT can ping  $local_tun_ip_addr or l2tpv3's LAN PC $local_tun_pc'"
            format "    2. l2tpv3 server can ping $peer_tun_ip_addr or DUT's  LAN PC $peer_tun_pc"
            format "    3. PC1($local_tun_pc) can ping $peer_tun_pc"
            format "    4. PC2($peer_tun_pc) can ping $local_tun_pc"
        else
            format "     1. PC1 ($local_PC)can ping $DUT_LAN_PC"
            format "     2. PC2 ($DUT_LAN_PC)can ping $local_PC"
        fi
        if [ "${protocol}" = "udp" ]; then
            format "sniffer wan package will be in UDP and Source Port/Dest Port = ${peer_port} or ${local_port}"
        fi
    fi
    echo "└────────────────────────────────────────────────────────────────────────────────────┘"
}

#default_conf

case $1 in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    status)
        query_status
        ;;
    *)
        echo -e "\n$0  [start | stop | restart | status ]\n"
        ;;
esac
