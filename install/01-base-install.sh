#!/bin/bash

pacstrap -i /mnt base git

genfstab -U -p /mnt >> /mnt/etc/fstab

git clone https://github.com/StancaRadu/arch-dotfiles.git /mnt/root/arch-dotfiles

arch-chroot /mnt/root/arch-dotfiles/install ./02-base-config.sh