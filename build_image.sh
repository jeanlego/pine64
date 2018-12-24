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

echo "Creating filesystems"

parted --script $IMAGE_NAME mklabel msdos
parted --script $IMAGE_NAME mkpart primary ext4 1MiB 100%
parted --script $IMAGE_NAME "set" 1 boot on

echo "Attaching loop device"
LOOP_DEVICE=$(losetup -f)
losetup -P $LOOP_DEVICE $IMAGE_NAME

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
    bsdtar -xpf "$(basename ${ROOTFS_URL})" -C "$TEMP_ROOT"
    echo "OK"
fi

cp extras/resize_rootfs.sh ${TEMP_ROOT}/opt/resize_rootfs.sh
cp extras/sysrq.conf ${TEMP_ROOT}/etc/sysctl.d/sysrq.conf
cp extras/change_hostname.sh ${TEMP_ROOT}/opt/change_hostname.sh
cp extras/change_hostname.service ${TEMP_ROOT}/etc/systemd/system/change_hostname.service
cp extras/.tmux.conf ${TEMP_ROOT}/root/.tmux.conf

sed -i 's|CheckSpace|#CheckSpace|' ${TEMP_ROOT}/etc/pacman.conf
cat extras/pacman.conf >> ${TEMP_ROOT}/etc/pacman.conf

rm -f ${TEMP_ROOT}/etc/sudoers
cp extras/sudoers ${TEMP_ROOT}/etc/sudoers

echo "Mounting system partitions for chrooting"
mv ${TEMP_ROOT}/etc/resolv.conf ${TEMP_ROOT}/etc/resolv.conf.bckup
cp /etc/resolv.conf ${TEMP_ROOT}/etc/resolv.conf
cp $(which qemu-${QEMU_ARCHES}-static) ${TEMP_ROOT}/usr/bin/qemu-${QEMU_ARCHES}-static
cp extras/second_phase.sh ${TEMP_ROOT}/opt/second_phase.sh

systemd-nspawn -D ${TEMP_ROOT} "/opt/second_phase.sh"

rm -f ${TEMP_ROOT}/opt/second_phase.sh
rm -f ${TEMP_ROOT}/usr/bin/qemu-*
rm -f ${TEMP_ROOT}/etc/resolv.conf
mv ${TEMP_ROOT}/etc/resolv.conf.bckup ${TEMP_ROOT}/etc/resolv.conf 


echo "Installing bootloader"
dd if=${TEMP_ROOT}/boot/u-boot-sunxi-with-spl-sopine.bin of=${LOOP_DEVICE} bs=8k seek=1

umount ${TEMP_ROOT}
losetup -d $LOOP_DEVICE
rm -Rf ${TEMP_ROOT}
