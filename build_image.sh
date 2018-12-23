#!/bin/bash

ROOT_DIR=${PWD}

# ensure running as root
if [ "$(id -u)" != "0" ]; then
    echo "This script requires root."
    exec sudo "$0" "$@" 
fi

IMAGE_NAME="sopine_arch_headless.img"
size_of_image="6G"
export LC_ALL=C

TEMP_ROOT="build"

QEMU_ARCHES="aarch64"
ROOTFS="ArchLinuxARM-${QEMU_ARCHES}-latest.tar.gz"
ROOTFS_URL="http://archlinuxarm.org/os/${ROOTFS}"

trap cleanup EXIT

cleanup() {
    losetup -d $LOOP_DEVICE
    umount ${TEMP_ROOT}

    rm -f ${IMAGE_NAME}
    rm -Rf ${TEMP_ROOT}
}

###################
# build the empty image
truncate -s $size_of_image $IMAGE_NAME

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

if [ ! -f ${ROOTFS} ]; then
    echo "Downloading rootfs tarball ..."
    wget $ROOTFS_URL
fi

sync

# Extract with BSD tar
echo -n "Extracting ... "
bsdtar -xpf "$ROOTFS" -C "$TEMP_ROOT"
echo "OK"

sync

sed -i 's|CheckSpace|#CheckSpace|' ${TEMP_ROOT}/etc/pacman.conf

cat extras/pacman.conf >> ${TEMP_ROOT}/etc/pacman.conf
cp extras/resize_rootfs.sh ${TEMP_ROOT}/opt/resize_rootfs.sh
cp extras/sysrq.conf ${TEMP_ROOT}/etc/sysctl.d/sysrq.conf
cp extras/change_hostname.sh ${TEMP_ROOT}/opt/change_hostname.sh
cp extras/change_hostname.service ${TEMP_ROOT}/etc/systemd/system/change_hostname.service

echo "Mounting system partitions for chrooting"
mv ${TEMP_ROOT}/etc/resolv.conf ${TEMP_ROOT}/etc/resolv.conf.bckup
cp /etc/resolv.conf ${TEMP_ROOT}/etc/resolv.conf
cp $(which qemu-${QEMU_ARCHES}-static) ${TEMP_ROOT}/usr/bin/qemu-${QEMU_ARCHES}-static
cp extras/second_phase.sh ${TEMP_ROOT}/opt/second_phase.sh

systemd-nspawn -D ${TEMP_ROOT} extras/second_phase.sh

rm -f ${TEMP_ROOT}/opt/second_phase.sh
rm -f ${TEMP_ROOT}/usr/bin/qemu-*
rm -f ${TEMP_ROOT}/etc/resolv.conf
mv ${TEMP_ROOT}/etc/resolv.conf.bckup ${TEMP_ROOT}/etc/resolv.conf 

umount ${TEMP_ROOT}

echo "Installing bootloader"
dd if=extras/u-boot-sunxi-with-spl-sopine.bin of=${LOOP_DEVICE} bs=8k seek=1

losetup -d $LOOP_DEVICE
rm -Rf ${TEMP_ROOT}

xz -k -v -1 --compress -T 2 ${IMAGE_NAME}
