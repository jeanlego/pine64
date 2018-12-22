#!/bin/bash

# ensure running as root
if [ "$(id -u)" != "0" ]; then
    echo "This script requires root."
    exec sudo "$0" "$@" 
fi

IMAGE_NAME="sopine_arch_headless.img"
size_of_image="6G"
export LC_ALL=C

TEMP_ROOT="build"

QEMU_ARCH="aarch64"
ROOTFS="ArchLinuxARM-${QEMU_ARCH}-latest.tar.gz"
ROOTFS_URL="http://archlinuxarm.org/os/${ROOTFS}"

trap cleanup EXIT

make_and_partition_image() {

    ###################
    # build the empty image
    truncate -s $size_of_image $IMAGE_NAME

    echo "Creating filesystems"

    parted --script $IMAGE_NAME mklabel msdos
    parted --script $IMAGE_NAME mkpart primary ext4 1MiB 100%
    parted --script $IMAGE_NAME "set" 1 boot on

    echo "Attaching loop device"
    TEMP_DEVICE=$(losetup -f)
    losetup -P $TEMP_DEVICE $IMAGE_NAME

    mkfs.ext4 -L root ${TEMP_DEVICE}p1
    losetup -d $TEMP_DEVICE || /bin/true
}

cleanup() {
    losetup -d $LOOP_DEVICE
    umount ${TEMP_ROOT}

    rm -f ${IMAGE_NAME}
    rm -Rf ${TEMP_ROOT}
}

ARCH_AVAILABLE=$(ls /usr/bin | grep qemu | grep static | cut -d '-' -f2)
if [ "_$(echo ${ARCH_AVAILABLE} | grep ${QEMU_ARCH})" == "" ]; then
    echo "${QEMU_ARCH} is not available on your system (/usr/bin)"
    exit 1
fi

BSD_TAR_V=$(bsdtar --version | tr -s ' ' | cut -d ' ' -f 2)
BSD_TAR_V_MAJOR=$(echo ${BSD_TAR_V} | cut -d '.' -f 1)
BSD_TAR_V_MINOR=$(echo ${BSD_TAR_V} | cut -d '.' -f 1)
if [ ${BSD_TAR_V_MAJOR} -ge "3" ] && [ ${BSD_TAR_V_MAJOR} -ge "3" ]; then
    echo "skipping local install of bsdtar"
else
    wget https://www.libarchive.org/downloads/libarchive-3.3.3.tar.gz
    tar xzf libarchive-3.3.3.tar.gz
    cd libarchive-3.3.3
    ./configure && make && make install
    cd ..
fi

make_and_partition_image

echo "Attaching loop device"
LOOP_DEVICE=$(losetup -f)
losetup -P $LOOP_DEVICE $IMAGE_NAME
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

mv ${TEMP_ROOT}/etc/resolv.conf ${TEMP_ROOT}/etc/resolv.conf.bckup
cp /etc/resolv.conf ${TEMP_ROOT}/etc/resolv.conf

sed -i 's|CheckSpace|#CheckSpace|' ${TEMP_ROOT}/etc/pacman.conf

cat >> ${TEMP_ROOT}/etc/pacman.conf <<EOF
[pine64-mainline]
SigLevel = Never
Server = https://github.com/anarsoul/PKGBUILDs/releases/download/mainline/
EOF

cat > ${TEMP_ROOT}/opt/resize_rootfs.sh <<EOF
#!/bin/sh

if [ "\$(id -u)" -ne "0" ]; then
    echo "This script requires root."
    exit 1
fi

parted /dev/mmcblk0 resize 1 100%
partx -u /dev/mmcblk0
resize2fs /dev/mmcblk0p1
EOF
chmod +x ${TEMP_ROOT}/opt/resize_rootfs.sh

cat > ${TEMP_ROOT}/etc/sysctl.d/sysrq.conf <<EOF
kernel.sysrq = 0
EOF

cat > ${TEMP_ROOT}/opt/change_hostname.sh <<EOF
#!/bin/bash
NEWNAME="device-\$(cat /sys/class/net/\$(ls /sys/class/net | grep -v "docker" | grep -v "lo" | head -n 1)/address | tr ':' '-')" 
echo "127.0.0.1 localhost" > /etc/hosts
hostnamectl set-hostname \${NEWNAME}
exit
EOF
chmod +x ${TEMP_ROOT}/opt/change_hostname.sh

cat > ${TEMP_ROOT}/etc/systemd/system/change_hostname.service <<EOF
[Unit]
Description=Set the hostname to the mac address
DefaultDependencies=no
After=sysinit.target
Before=basic.target

[Service]
Type=oneshot
ExecStart=/opt/change_hostname.sh
TimeoutSec=0

[Install]
WantedBy=basic.target
EOF

echo "Mounting system partitions for chrooting"

cp /usr/bin/qemu-${QEMU_ARCH}-static ${TEMP_ROOT}/usr/bin/qemu-${QEMU_ARCH}-static || /bin/true
systemd-nspawn -D ${TEMP_ROOT} bin/bash <<EOF
unset LD_PRELOAD 

groupadd casaadmin
usermod -d /home/casaadmin -m -g casaadmin -l casaadmin alarm
usermod -a -G wheel casaadmin

echo -e "forgetme\nforgetme" | passwd casaadmin
echo -e "forgetme\nforgetme" | passwd
passwd -e casaadmin

pacman-key --init
pacman-key --populate archlinuxarm
killall -KILL gpg-agent
pacman -Syu --noconfirm
pacman -Rsn --noconfirm linux-aarch64
pacman -Syu --noconfirm --needed zsh dosfstools curl xz netctl dialog \
	pv linux-pine64 linux-pine64-headers uboot-pine64-git filesystem \
    autoconf automake binutils bison fakeroot file findutils flex gawk gcc gettext grep groff \
    gzip libtool m4 make patch pkgconf sed sudo texinfo util-linux which docker cmake \
    git llvm clang bc unzip rsync wget curl vim cpio bison flex python gdb valgrind tmux \
    zsh-theme-powerlevel9k powerline-fonts

sed -i 's|^#en_US.UTF-8|en_US.UTF-8|' /etc/locale.gen
cd /usr/share/i18n/charmaps
gzip -d UTF-8.gz
locale-gen
gzip UTF-8

sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config

sed -i 's/#%wheel[\s]+ALL=(ALL)[\s]+ALL//g' /etc/sudoers
echo -e "%wheel\tALL=(ALL) ALL" >> /etc/sudoers
usermod -a -G docker casaadmin

# install nicer theme
echo 'source /usr/share/zsh-theme-powerlevel9k/powerlevel9k.zsh-theme' >> /home/casaadmin/.zshrc
echo 'source /usr/share/zsh-theme-powerlevel9k/powerlevel9k.zsh-theme' >> /root/.zshrc

usermod -s /bin/zsh casaadmin
usermod -s /bin/zsh root

systemctl enable change_hostname
systemctl enable sshd
systemctl enable docker

yes | pacman -Scc
exit 0
EOF

# make it use tmux if it is a remote connection
echo "\
[[ -z \"\${TMUX}\" ]] && [ \"\${SSH_CONNECTION}\" != \"\" ] && tmux new-session -A -s \${USER}
$(cat ${TEMP_ROOT}/home/casaadmin/.zshrc)\
" > ${TEMP_ROOT}/home/casaadmin/.zshrc 

rm ${TEMP_ROOT}/usr/bin/qemu-${QEMU_ARCH}-static || /bin/true
rm ${TEMP_ROOT}/etc/resolv.conf
mv ${TEMP_ROOT}/etc/resolv.conf.bckup ${TEMP_ROOT}/etc/resolv.conf

umount ${TEMP_ROOT}

echo "Installing bootloader"
dd if=u-boot-sunxi-with-spl-sopine.bin of=${LOOP_DEVICE} bs=8k seek=1

losetup -d $LOOP_DEVICE
rm -Rf ${TEMP_ROOT}

xz -k -v --compress -T 0 ${IMAGE_NAME}
