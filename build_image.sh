#!/bin/bash

ROOT_DIR=${PWD}
export LC_ALL=C
TEMP_ROOT="build"

# ensure running as root
if [ "$(id -u)" != "0" ]; then
    echo "This script requires root."
    exec sudo "$0" "$@" 
fi

IMAGE_NAME=$1
if [ "_${IMAGE_NAME}" == "_" ]
then
    echo "please specify an image name"
    exit 1
fi

IMAGE_SIZE=$2
if [ "_${IMAGE_SIZE}" == "_" ]
then
    echo "please specify a size for the image ie. 3G or 300M"
    exit 1
fi

###################
# build the empty image
truncate -s $IMAGE_SIZE $IMAGE_NAME

echo "Attaching loop device"
LOOP_DEVICE=$(losetup -f)
losetup $LOOP_DEVICE $IMAGE_NAME

# zero the beginning of the image
dd if=/dev/zero of=$LOOP_DEVICE bs=1M count=32

echo "Creating filesystems"
(
echo o # Create a new empty DOS partition table
echo n # Add a new partition
echo p # Primary partition
echo 1 # Partition number
echo 32768
echo   # Last sector (Accept default: varies)
echo p # print layout
echo w # Write changes
) | sudo fdisk $LOOP_DEVICE

echo "Setting up idbloader"
wget http://os.archlinuxarm.org/os/rockchip/boot/rock64/idbloader.img
dd if=idbloader.img of=$LOOP_DEVICE seek=64 conv=notrunc

echo "Setting up uboot"
wget http://os.archlinuxarm.org/os/rockchip/boot/rock64/uboot.img
dd if=uboot.img of=$LOOP_DEVICE seek=16384 conv=notrunc

echo "Setting up trust"
wget http://os.archlinuxarm.org/os/rockchip/boot/rock64/trust.img
dd if=trust.img of=$LOOP_DEVICE seek=24576 conv=notrunc

mkfs.ext4 -L root ${LOOP_DEVICE}p1

echo "Mounting rootfs"
mkdir -p ${TEMP_ROOT}
mount ${LOOP_DEVICE}p1 $TEMP_ROOT

echo "mounted the image on ${LOOP_DEVICE}->$TEMP_ROOT"

sync

trap cleanup EXIT

cleanup() {
    losetup -d $LOOP_DEVICE
    umount ${TEMP_ROOT}
    rm -Rf ${TEMP_ROOT}
}

QEMU_ARCHES=$3
if [ "_${QEMU_ARCHES}" == "_" ]
then
    echo "please specify an architecture"
    exit 1
fi

ROOTFS_URL=$4
if [ "_${ROOTFS_URL}" == "_" ]
then
    echo "please specify an URL for the rootfs"
    exit 1
else
    echo "Downloading rootfs tarball ..."
    wget $ROOTFS_URL || (echo "cannot download image" && exit 1)
    # Extract with BSD tar
    echo -n "Extracting ... "
    bsdtar -xpf "$(basename ${ROOTFS_URL})" -C "${TEMP_ROOT}"
    echo "OK"
fi

echo "placing boot.scr @ /boot"
wget http://os.archlinuxarm.org/os/rockchip/boot/rock64/boot.scr -O ${TEMP_ROOT}/boot/boot.scr

echo "Mounting system partitions for chrooting"
mv ${TEMP_ROOT}/etc/resolv.conf ${TEMP_ROOT}/etc/resolv.conf.bckup
cp /etc/resolv.conf ${TEMP_ROOT}/etc/resolv.conf
cp $(which qemu-${QEMU_ARCHES}-static) ${TEMP_ROOT}/usr/bin/qemu-${QEMU_ARCHES}-static

cp second_phase.sh ${TEMP_ROOT}/opt/second_phase.sh
systemd-nspawn -D ${TEMP_ROOT} "/opt/second_phase.sh"
rm -f ${TEMP_ROOT}/opt/second_phase.sh

rm -f ${TEMP_ROOT}/usr/bin/qemu-*
rm -f ${TEMP_ROOT}/etc/resolv.conf
mv ${TEMP_ROOT}/etc/resolv.conf.bckup ${TEMP_ROOT}/etc/resolv.conf 

umount ${TEMP_ROOT}
losetup -d $LOOP_DEVICE
rm -Rf ${TEMP_ROOT}




