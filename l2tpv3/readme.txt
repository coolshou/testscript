# L2TPv3


# vlan (require 8021q)

modprobe 8021q
lsmod |grep  8021q

### us  ip  to setup vlan

ip -d link show l2tpeth0
# should have  following line
vlan protocol 802.1Q id 10 <REORDER_HDR>

# add vlan
ip link add link l2tpeth0 name l2tpeth0.10 type vlan id 10
