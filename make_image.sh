#!/bin/bash
trap cleanup EXIT

set -e
set -x
export LC_ALL=C

IMAGE_NAME="$1"
BOOTLOADER="$2"

if [ -z "$IMAGE_NAME" ] || [ -z "$BOOTLOADER" ]; then
	echo "Usage: $0 <image name> <bootloader>"
	exit 1
fi

if [ "$(id -u)" -ne "0" ]; then
	echo "This script requires root."
	exit 1
fi

BUILD="build"
BUILD_ARCH=arm64

DEST=$(mktemp -d)
mkdir -p $DEST

ROOTFS="http://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"

mkdir -p $BUILD
TARBALL="$BUILD/$(basename $ROOTFS)"
if [ ! -e "$TARBALL" ]; then
	echo "Downloading rootfs tarball ..."
	wget -O "$TARBALL" "$ROOTFS"
fi

cleanup() {
	if [ -e "$DEST/proc/cmdline" ]; then
		umount "$DEST/proc"
	fi
	if [ -d "$DEST/sys/kernel" ]; then
		umount "$DEST/sys"
	fi
	umount "$DEST/dev" || true
	umount "$DEST/tmp" || true
	if [ -d "$TEMP" ]; then
		rm -rf "$TEMP"
	fi
}

do_chroot() {
	cmd="$@"
	mount -o bind /tmp "$DEST/tmp"
	mount -o bind /dev "$DEST/dev"
	chroot "$DEST" mount -t proc proc /proc
	chroot "$DEST" mount -t sysfs sys /sys
	chroot "$DEST" $cmd
	chroot "$DEST" umount /sys
	chroot "$DEST" umount /proc
	umount "$DEST/dev"
	umount "$DEST/tmp"
}

# make the empty image
IMAGE_SIZE=6144M
PART_POSITION=20480 # K
FAT_SIZE=100 #M
SWAP_SIZE=2048 # M

fallocate -l $IMAGE_SIZE $IMAGE_NAME

cat << EOF | fdisk $IMAGE_NAME
o
n
p
1
$((PART_POSITION*2))
+${FAT_SIZE}M
t
c
n
p
2
$((PART_POSITION*2+FAT_SIZE*1024*2))
+${SWAP_SIZE}M
t
2
82
n
p
3
$((PART_POSITION*2+FAT_SIZE*1024*2+SWAP_SIZE*1024*2))

t
3
83
a
3
w
EOF

echo "Done empty image"

echo "Attaching loop device"
LOOP_DEVICE=$(losetup -f)
losetup -P $LOOP_DEVICE $IMAGE_NAME

echo "Creating filesystems"
mkfs.vfat ${LOOP_DEVICE}p1
mkswap ${LOOP_DEVICE}p2
mkfs.ext4 ${LOOP_DEVICE}p3

echo "Mounting rootfs"
mount ${LOOP_DEVICE}p3 $DEST

# Extract with BSD tar
echo -n "Extracting ... "
set -x
bsdtar -xpf "$TARBALL" -C "$DEST"
echo "OK"

# Add qemu emulation.
cp /usr/bin/qemu-aarch64-static "$DEST/usr/bin"
cp /usr/bin/qemu-arm-static "$DEST/usr/bin"

mv "$DEST/etc/resolv.conf" "$DEST/etc/resolv.conf.dist"
cp /etc/resolv.conf "$DEST/etc/resolv.conf"
sed -i 's|CheckSpace|#CheckSpace|' "$DEST/etc/pacman.conf"

cat >> "$DEST/etc/pacman.conf" <<EOF
[pine64-mainline]
SigLevel = Never
Server = https://github.com/anarsoul/PKGBUILDs/releases/download/mainline/
EOF

cat > "$DEST/second-phase" <<EOF
#!/bin/sh
pacman-key --init
pacman-key --populate archlinuxarm
killall -KILL gpg-agent
pacman -Sy --noconfirm
pacman -Rsn --noconfirm linux-aarch64
pacman -S --noconfirm --needed dosfstools curl xz iw rfkill netctl dialog \
	pv linux-pine64 linux-pine64-headers uboot-pine64-git

usermod -a -G network,video,audio,optical,storage,input,scanner,games,lp,rfkill alarm

sed -i 's|^#en_US.UTF-8|en_US.UTF-8|' /etc/locale.gen
cd /usr/share/i18n/charmaps
# locale-gen can't spawn gzip when running under qemu-user, so ungzip charmap before running it
# and then gzip it back
gzip -d UTF-8.gz
locale-gen
gzip UTF-8
yes | pacman -Scc
EOF

chmod +x "$DEST/second-phase"
do_chroot /second-phase
rm $DEST/second-phase

# Final touches
rm "$DEST/usr/bin/qemu-aarch64-static"
rm "$DEST/usr/bin/qemu-arm-static"
rm -f "$DEST"/*.core
mv "$DEST/etc/resolv.conf.dist" "$DEST/etc/resolv.conf"

cp resize_rootfs.sh $DEST/usr/local/sbin/
echo "kernel.sysrq = 0" > $DEST/etc/sysctl.d/sysrq.conf

echo "Installing bootloader"
dd if=$DEST/boot/$BOOTLOADER of=${LOOP_DEVICE} bs=8k seek=1

echo "Unmounting rootfs"
umount $DEST
rm -rf $DEST

# Detach loop device
losetup -d $LOOP_DEVICE

