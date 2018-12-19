#!/bin/bash
trap cleanup EXIT
set -e
set -x
export LC_ALL=C

IMAGE_NAME=archlinux-sopine-headless.img

DEST=$(mktemp -d)
mkdir -p $DEST

cleanup() {

	umount "$DEST/proc" || /bin/true
	umount "$DEST/sys" || /bin/true
	umount "$DEST/dev" || /bin/true
	umount "$DEST/tmp" || /bin/true
	umount $DEST || /bin/true

	echo "Unmounting rootfs"
	rm -rf $DEST || /bin/true
	# Detach loop device
	losetup -d $LOOP_DEVICE || /bin/true
}

ROOTFS_FILENAME=ArchLinuxARM-aarch64-latest.tar.gz
ROOTFS="http://archlinuxarm.org/os/${ROOTFS_FILENAME}"

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

if [ "$(id -u)" -ne "0" ]; then
	echo "This script requires root."
	exit 1
fi

echo "Downloading rootfs tarball ..."
wget ${ROOTFS}

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
echo "Attaching loop device"
LOOP_DEVICE=$(losetup -f)
losetup -P $LOOP_DEVICE $IMAGE_NAME

echo "Creating filesystems"
mkfs.vfat ${LOOP_DEVICE}p1
mkswap ${LOOP_DEVICE}p2
mkfs.ext4 -F ${LOOP_DEVICE}p3

echo "Mounting rootfs"
mount ${LOOP_DEVICE}p3 $DEST

# Extract with BSD tar
echo -n "Extracting ... "
bsdtar -xpf ${ROOTFS_FILENAME} -C ${DEST}
echo "OK"

# Add qemu emulation.
cp /usr/bin/qemu-aarch64-static "$DEST/usr/bin"
cp /usr/bin/qemu-arm-static "$DEST/usr/bin"

mv "$DEST/etc/resolv.conf" "$DEST/etc/resolv.conf.dist"
cp /etc/resolv.conf "$DEST/etc/resolv.conf"

sed -i 's|CheckSpace|#CheckSpace|' "$DEST/etc/pacman.conf"

cat >> "$DEST/etc/pacman.conf" <<EOF
[pine64-mainline]
SigLevel = Optional TrustAll
Server = https://github.com/anarsoul/PKGBUILDs/releases/download/mainline/
EOF

cat > "$DEST/second-phase" <<EOF
#!/bin/sh
pacman-key --init
pacman-key --populate archlinuxarm
killall -KILL gpg-agent
pacman -Sy --noconfirm
pacman -Rsn --noconfirm linux-aarch64
pacman -S --noconfirm --needed git
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
rm -f "$DEST"/*.core
mv "$DEST/etc/resolv.conf.dist" "$DEST/etc/resolv.conf"

cp resize_rootfs.sh $DEST/usr/local/sbin/
echo "kernel.sysrq = 0" > $DEST/etc/sysctl.d/sysrq.conf

echo "Installing bootloader"
dd if="$DEST/boot/u-boot-sunxi-with-spl-sopine.bin" of="${LOOP_DEVICE}" bs=8k seek=1





