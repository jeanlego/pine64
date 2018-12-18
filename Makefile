export RELEASE_NAME ?= $(shell date +%Y%m%d)

rootfs-$(RELEASE_NAME).tar.gz:
	./make_rootfs.sh rootfs-$(RELEASE_NAME) $@

archlinux-sopine-$(RELEASE_NAME).img: rootfs-$(RELEASE_NAME).tar.gz
	./make_empty_image.sh $@
	./make_image.sh $@ $< u-boot-sunxi-with-spl-sopine.bin
	
.PHONY: archlinux-sopine
archlinux-sopine: archlinux-sopine-$(RELEASE_NAME).img
