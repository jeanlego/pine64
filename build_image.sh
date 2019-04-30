#!/bin/bash

set -e

export LC_ALL=C
TEMP_ROOT=$(mktemp -d)
IMAGE_NAME="aarch64_headless.img"
FINISHED="false"

# ensure running as root
if [ "$(id -u)" != "0" ]; then
    echo "This script requires root."
    exec sudo "$0" "$@" 
fi

trap cleanup EXIT

cleanup() {
    echo "unmounting the fakeroot"
    sync
    umount ${TEMP_ROOT}     2>&1 > /dev/null || /bin/true
    rm -Rf ${TEMP_ROOT}     2>&1 > /dev/null || /bin/true
    losetup -d ${LOOP_DEVICE} 2>&1 > /dev/null || /bin/true
    if [ "${FINISHED}" == "false" ]; then
        rm -f ${IMAGE_NAME}
    fi
}

###################
# build the empty image
truncate -s 4G ${IMAGE_NAME}

parted --script ${IMAGE_NAME} mklabel msdos

echo "Setting up idbloader"
[ ! -f idbloader.img ] && wget http://os.archlinuxarm.org/os/rockchip/boot/rock64/idbloader.img
dd if=idbloader.img of=${IMAGE_NAME} seek=64 conv=notrunc

echo "Setting up uboot"
[ ! -f uboot.img ] && wget http://os.archlinuxarm.org/os/rockchip/boot/rock64/uboot.img
dd if=uboot.img of=${IMAGE_NAME} seek=16384 conv=notrunc

echo "Setting up trust"
[ ! -f trust.img ] && wget http://os.archlinuxarm.org/os/rockchip/boot/rock64/trust.img
dd if=trust.img of=${IMAGE_NAME} seek=24576 conv=notrunc

parted --script ${IMAGE_NAME} mkpart primary ext4 32768s 100%
parted --script ${IMAGE_NAME} "set" 1 boot on

echo "Attaching loop device"
LOOP_DEVICE=$(losetup -f)
losetup -P ${LOOP_DEVICE} ${IMAGE_NAME}

mkfs.ext4 -L root ${LOOP_DEVICE}p1

echo "Mounting rootfs"
mkdir -p ${TEMP_ROOT}
mount ${LOOP_DEVICE}p1 ${TEMP_ROOT} 
sync

echo "mounted the image on ${LOOP_DEVICE}p1->${TEMP_ROOT}"

echo "Downloading rootfs tarball ..."
[ ! -f ArchLinuxARM-aarch64-latest.tar.gz ] && wget http://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz

echo "Extracting rootfs tarball ..."
bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C "${TEMP_ROOT}"

echo "placing boot.scr @ /boot"
wget http://os.archlinuxarm.org/os/rockchip/boot/rock64/boot.scr -O ${TEMP_ROOT}/boot/boot.scr

echo "Mounting system partitions for chrooting"
mv ${TEMP_ROOT}/etc/resolv.conf ${TEMP_ROOT}/etc/resolv.conf.bckup
cp /etc/resolv.conf ${TEMP_ROOT}/etc/resolv.conf
cp $(which qemu-aarch64-static) ${TEMP_ROOT}/usr/bin/qemu-aarch64-static
cp second_phase.sh ${TEMP_ROOT}/opt/second_phase.sh

systemd-nspawn -D ${TEMP_ROOT} "/opt/second_phase.sh"

rm -f ${TEMP_ROOT}/opt/second_phase.sh
rm -f ${TEMP_ROOT}/usr/bin/qemu-*
rm -f ${TEMP_ROOT}/etc/resolv.conf
mv ${TEMP_ROOT}/etc/resolv.conf.bckup ${TEMP_ROOT}/etc/resolv.conf 

FINISHED="true"