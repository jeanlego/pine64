#!/bin/bash
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