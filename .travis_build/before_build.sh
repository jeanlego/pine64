#!/bin/bash

sed -i 's/xenial/disco/g' /etc/apt/sources.list
apt-get update
apt-get install binfmt-support systemd-container qemu-user-static bsdtar
sed -i 's/disco/xenial/g' /etc/apt/sources.list
apt-get update

