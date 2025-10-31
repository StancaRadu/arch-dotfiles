#!/bin/bash

source /root/arch-dotfiles/install.conf

if [[ -z "$TARGET_DEVICE" ]]; then
  read -rp "Enter target device (e.g. /dev/sda): " TARGET_DEVICE
  export TARGET_DEVICE
  # Optionally, save it back to the config file:
  sed -i "s|^TARGET_DEVICE=.*|TARGET_DEVICE=\"$TARGET_DEVICE\"|" /root/arch-dotfiles/install.conf
fi

mkdir /boot/EFI
mount "${TARGER_DEVICE}1" /boot/EFI
grub-install --target=x86_64-efi --bootloader-id=grup_uefi --recheck