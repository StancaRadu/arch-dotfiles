#!/bin/bash

source ./install.conf

echo "Set root password:"
passwd

if [[ -z "$USERNAME" ]]; then
  read -rp "Enter username for main user" USERNAME

useradd -m -g users -G wheel "$USERNAME"

echo "Set password for user $USERNAME:"
passwd "$USERNAME"

cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
grub-mkconfig -o /boot/grub/grub.cfg

bash ./05-bootloader.sh