#!/bin/bash
ROOT_DIR=${PWD}

# ensure running as root
if [ "$(id -u)" != "0" ]; then
    echo "This script requires root."
    exec sudo "$0" "$@" 
fi

SRC=$1
cd ${SRC}

DESTINATION=$2

IMAGE_NAME="sopine_arch_headless.img"
size_of_image="6G"
export LC_ALL=C

TEMP_ROOT="build"

QEMU_ARCH="aarch64"
ROOTFS="ArchLinuxARM-${QEMU_ARCH}-latest.tar.gz"
ROOTFS_URL="http://archlinuxarm.org/os/${ROOTFS}"

trap cleanup EXIT

cleanup() {
    losetup -d $LOOP_DEVICE
    umount ${TEMP_ROOT}

    rm -f ${IMAGE_NAME}
    rm -Rf ${TEMP_ROOT}
}

install_bsdtar() {
    
    VERSION="3.3.3"
    FILE="libarchive-${VERSION}"
    ARCHIVE="${FILE}.tar.gz"

    test -f ${ARCHIVE} || wget "https://www.libarchive.org/downloads/${ARCHIVE}"
    tar xzf ${ARCHIVE}
    cd ${FILE}

    ./configure

    make -j4
    make install
    cd ${ROOT_DIR}
}

BSD_TAR_V=$(bsdtar --version | tr -s ' ' | cut -d ' ' -f 2)
BSD_TAR_V_MAJOR=$(echo ${BSD_TAR_V} | cut -d '.' -f 1)
BSD_TAR_V_MINOR=$(echo ${BSD_TAR_V} | cut -d '.' -f 2)
if [ ${BSD_TAR_V_MAJOR} -ge "3" ] && [ ${BSD_TAR_V_MAJOR} -ge "3" ]; then
    echo "skipping local install of bsdtar"
else
    install_bsdtar
fi

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
cp $(which qemu-${QEMU_ARCH}-static) ${TEMP_ROOT}/usr/bin/qemu-${QEMU_ARCH}-static

systemd-nspawn -D ${TEMP_ROOT} extras/second_phase.sh

rm -f ${TEMP_ROOT}/usr/bin/qemu-*
rm -f ${TEMP_ROOT}/etc/resolv.conf
mv ${TEMP_ROOT}/etc/resolv.conf.bckup ${TEMP_ROOT}/etc/resolv.conf

# make it use tmux if it is a remote connection
printf  "\
[[ -z \"\${TMUX}\" ]] && [ \"\${SSH_CONNECTION}\" != \"\" ] && tmux new-session -A -s \${USER} \n\
$(cat ${TEMP_ROOT}/home/casaadmin/.zshrc)\
" > ${TEMP_ROOT}/home/casaadmin/.zshrc 

umount ${TEMP_ROOT}

echo "Installing bootloader"
dd if=u-boot-sunxi-with-spl-sopine.bin of=${LOOP_DEVICE} bs=8k seek=1

losetup -d $LOOP_DEVICE
rm -Rf ${TEMP_ROOT}

xz -k -v -1 --compress -T 2 ${IMAGE_NAME}

cp ${IMAGE_NAME}.xz ${DESTINATION}/${IMAGE_NAME}.xz
