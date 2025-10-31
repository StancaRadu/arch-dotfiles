#!/bin/bash

pacstrap -i /mnt base

genfstab -U -p /mnt >> /mnt/etc/fstab

arch-chroot /mnt

bash ./02-base-config.sh