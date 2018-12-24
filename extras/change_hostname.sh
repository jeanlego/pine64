#!/bin/bash
NEWNAME="device-$(cat /sys/class/net/$(ls /sys/class/net | grep -v "docker" | grep -v "lo" | head -n 1)/address | tr ':' '-')" 
echo "127.0.0.1 localhost" > /etc/hosts
hostnamectl set-hostname ${NEWNAME}
exit 0
