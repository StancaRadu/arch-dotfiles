#!/bin/bash
source /root/arch-dotfiles/install.conf


# Load package lists
BASE_PACKAGES=$(cat ../packages/base.txt)

# Install
sudo pacman -S --needed $BASE_PACKAGES

systemctl enable NetworkManager
systemctl enable sshd
systemctl enable gdm

bash ./04-user-setup.sh