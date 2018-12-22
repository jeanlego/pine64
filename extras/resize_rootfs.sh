#!/bin/sh

if [ "\$(id -u)" -ne "0" ]; then
    echo "This script requires root."
    exit 1
fi

parted /dev/mmcblk0 resize 1 100%
partx -u /dev/mmcblk0
resize2fs /dev/mmcblk0p1