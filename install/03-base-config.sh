#!/bin/bash

source /root/arch-dotfiles/install.conf

echo "The next command will open the mkinitcpio.conf file in nano editor. Look for the HOOKS= line and ensure 'encrypt' and 'lvm2' are included after 'block'. Save and exit."
read -p "Press Enter to continue..."

nano /etc/mkinitcpio.conf

mkinitcpio -p linux

echo "The next command will open the locale.gen file in nano editor. Uncomment your desired locales (e.g., en_US.UTF-8 UTF-8). Save and exit."
read -p "Press Enter to continue..."
nano /etc/locale.gen
locale-gen

if [[ -z "$TARGET_DEVICE" ]]; then
  read -rp "Enter target device (e.g. /dev/sda): " TARGET_DEVICE
  export TARGET_DEVICE
  # Optionally, save it back to the config file:
  sed -i "s|^TARGET_DEVICE=.*|TARGET_DEVICE=\"$TARGET_DEVICE\"|" /root/arch-dotfiles/install.conf
fi

echo "The next command will open the grub configuration file in nano editor. Ensure the GRUB_CMDLINE_LINUX_DEFAULT line includes cryptdevice={$TARGER_DEVICE3}3:vg0 before quiet. Save and exit."
read -p "Press Enter to continue..."
nano /etc/etc/grub

bash ./04-user-setup.sh