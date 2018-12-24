#!/bin/bash
unset LD_PRELOAD 

echo "\

[pine64-mainline]
SigLevel = Never
Server = https://github.com/anarsoul/PKGBUILDs/releases/download/mainline/
" >> /etc/pacman.conf
sed -i 's|CheckSpace|#CheckSpace|' /etc/pacman.conf

echo "\
kernel.sysrq = 0
" > /etc/sysctl.d/sysrq.conf

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
    zsh-theme-powerlevel9k powerline-fonts xterm distcc

yes | pacman -Scc

sed -i 's|^#en_US.UTF-8|en_US.UTF-8|' /etc/locale.gen
cd /usr/share/i18n/charmaps
gzip -d UTF-8.gz
locale-gen
gzip UTF-8

systemctl enable change_hostname
systemctl enable sshd
systemctl enable docker

groupadd casaadmin
usermod -d /home/casaadmin -m -g casaadmin -l casaadmin alarm
usermod -a -G wheel,docker casaadmin

chown -Rf casaadmin:wheel /home/casaadmin

usermod -s /bin/zsh casaadmin
usermod -s /bin/zsh root

sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config

sed -i 's/#[\s]+%wheel[\s]+ALL=(ALL)[\s]+ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers

echo -e "forgetme\nforgetme" | passwd casaadmin
echo -e "forgetme\nforgetme" | passwd
passwd -e casaadmin
passwd -e root

echo "\
export LANG=\"en_us.UTF-8\"
export TERM=\"xterm-256color\"

[[ -z \"\${TMUX}\" ]] && [ \"\${SSH_CONNECTION}\" != \"\" ] && tmux new-session -A -s \${USER} 

autoload -Uz compinit promptinit

compinit
promptinit

source /usr/share/zsh-theme-powerlevel9k/powerlevel9k.zsh-theme
" > /home/casaadmin/.zshrc
cat /home/casaadmin/.zshrc > /root/.zshrc

echo "\
set -g mouse on
" > /home/casaadmin/.tmux.conf 
cat /home/casaadmin/.tmux.conf  > /root/.tmux.conf 

exit 0
