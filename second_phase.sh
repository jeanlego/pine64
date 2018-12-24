#!/bin/bash
unset LD_PRELOAD 

echo "\

[pine64-mainline]
SigLevel = Never
Server = https://github.com/anarsoul/PKGBUILDs/releases/download/mainline/
" >> /etc/pacman.conf
sed -i '/CheckSpace/s/^#[[:space:]]*//g' /etc/pacman.conf

echo "\
kernel.sysrq = 0
" > /etc/sysctl.d/sysrq.conf

echo "\
127.0.0.1 localhost
" > /etc/hosts

echo "\
#!/bin/bash

" > /opt/first_boot.sh
chmod +x /opt/first_boot.sh

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
    zsh-theme-powerlevel9k powerline-fonts xterm distcc parted

yes | pacman -Scc

sed -i '/en_US.UTF-8/s/^#[[:space:]]*//g' /etc/locale.gen
cd /usr/share/i18n/charmaps
gzip -d UTF-8.gz
locale-gen
gzip UTF-8

systemctl enable sshd
systemctl enable docker

groupadd casaadmin
usermod -d /home/casaadmin -m -g casaadmin -l casaadmin alarm
usermod -a -G wheel,docker casaadmin

chown -Rf casaadmin:wheel /home/casaadmin

usermod -s /bin/zsh casaadmin
usermod -s /bin/zsh root

sed -i '/PermitRootLogin/s/[[:space:]]*yes/ no/g' /etc/ssh/sshd_config
sed -i '/%wheel[[:space:]]*ALL=(ALL)[[:space:]]*ALL/s/^#[[:space:]]*//g' /etc/sudoers

echo -e "forgetme\nforgetme" | passwd casaadmin
echo -e "forgetme\nforgetme" | passwd
passwd -e casaadmin
passwd -e root

echo "\
export LANG=\"en_us.UTF-8\"
export TERM=\"xterm-256color\"

if [[ -z \"\${TMUX}\" ]] && [ \"\${SSH_CONNECTION}\" != \"\" ];
then  
    tmux new-session -A -s \${USER} 
    exit
fi

autoload -Uz compinit promptinit

compinit
promptinit

source /usr/share/zsh-theme-powerlevel9k/powerlevel9k.zsh-theme
" > /root/.zshrc

echo "\
export LANG=\"en_us.UTF-8\"
export TERM=\"xterm-256color\"

if [ \"_\$(hostname | grep device)\" == \"_\" ]; then

    echo \" this is your first boot, we will help you set things up! :) \"

    NEW_NAME=\"device-\$(sed 's/:/-/g' /sys/class/net/eth0/address)\"
    echo \"###############
    first we will rename hostname to \${NEW_NAME}\"
    hostnamectl set-hostname \${NEW_NAME}

    echo \"###############
    we will help you resize the root partition\"
    parted /dev/mmcblk0 resize 1
    partx -u /dev/mmcblk0
    resize2fs /dev/mmcblk0p1

    echo \"###############
    Done initial boot now rebooting!\"

    sudo reboot
    exit
fi

if [[ -z \"\${TMUX}\" ]] && [ \"\${SSH_CONNECTION}\" != \"\" ];
then  
    tmux new-session -A -s \${USER} 
    exit
fi

autoload -Uz compinit promptinit

compinit
promptinit

source /usr/share/zsh-theme-powerlevel9k/powerlevel9k.zsh-theme

" > /home/casaadmin/.zshrc

echo "\
set -g mouse on
" > /home/casaadmin/.tmux.conf 
cat /home/casaadmin/.tmux.conf  > /root/.tmux.conf 

exit 0
