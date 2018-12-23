#!/bin/bash

sed -i 's/xenial/cosmic/g' /etc/apt/sources.list
apt-get update
apt-get install binfmt-support systemd-container qemu-user-static
sed -i 's/cosmic/xenial/g' /etc/apt/sources.list
