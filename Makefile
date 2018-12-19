rootfs-release.tar.gz:
	./make_rootfs.sh rootfs-release $@

archlinux-sopine-headless.img: rootfs-release.tar.gz
	./make_empty_image.sh $@
	./make_image.sh $@ $< u-boot-sunxi-with-spl-sopine.bin
	
.PHONY: archlinux-sopine
archlinux-sopine: archlinux-sopine-headless.img
