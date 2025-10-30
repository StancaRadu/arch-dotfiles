#!/bin/bash

echo
echo "Available disk devices:"
echo "-----------------------"
lsblk -pn -o NAME,MODEL,SIZE,TYPE,MOUNTPOINT | sed 's/^/  /'
echo "-----------------------"
echo
echo "WARNING: Formatting or partitioning will destroy all data on the selected device."
echo "         Double-check the device path and ensure it's the correct one (e.g., not your host disk if in a VM)."
echo "         Consider taking a VM snapshot or backup before proceeding."
echo
while true; do
  read -r -p "Enter device path (e.g. /dev/sda) or 'q' to abort: " sel
  [[ -z "$sel" ]] && continue
  if [[ "$sel" =~ ^[Qq]$ ]]; then
    echo "Aborted."
    exit 1
  fi
  if [[ ! "$sel" =~ ^/dev/ ]]; then
    echo "Provide a full path starting with /dev/."
    continue
  fi
  if [[ ! -b "$sel" ]]; then
    echo "Not a valid block device: $sel"
    continue
  fi
  read -r -p "Confirm $sel? [y/N]: " confirm
  case "${confirm,,}" in
    y|yes)
      TARGET_DEVICE="$sel"
      export TARGET_DEVICE
      echo "Selected: $TARGET_DEVICE"
      break
      ;;
    *)
      echo "Canceled. Try again."
      ;;
  esac
done

echo
echo "WARNING: Clearing the disk will delete ALL partitions and data on $TARGET_DEVICE."
echo "         This action is irreversible. Ensure you have backups."
read -r -p "Type 'CLEAR' to proceed or anything else to abort: " clear_confirm
if [[ "$clear_confirm" != "CLEAR" ]]; then
  echo "Aborted disk clearing."
  exit 1
fi

echo "Partitioning $TARGET_DEVICE..."
# Ask for partition sizes (with defaults) - now in MiB for consistency
read -r -p "EFI partition size in MiB (default 512): " efi_size
efi_size="${efi_size:-512}"
read -r -p "Boot partition size in MiB (default 1024): " boot_size
boot_size="${boot_size:-1024}"
read -r -p "Root LV size (e.g., 50G or 51200M, default 10G): " root_size
root_size="${root_size:-10G}"

# Wipe any existing partition table and signatures
wipefs -a "$TARGET_DEVICE" 2>/dev/null

# Calculate partition boundaries in MiB (ensures 1MiB alignment)
efi_start=1
efi_end=$((efi_start + efi_size))
boot_start=$efi_end
boot_end=$((boot_start + boot_size))
lvm_start=$boot_end

# Partition with parted using MiB units for proper alignment
parted "$TARGET_DEVICE" --script --align optimal mklabel gpt
parted "$TARGET_DEVICE" --script --align optimal mkpart primary fat32 ${efi_start}MiB ${efi_end}MiB
parted "$TARGET_DEVICE" --script set 1 esp on
parted "$TARGET_DEVICE" --script --align optimal mkpart primary ext4 ${boot_start}MiB ${boot_end}MiB
parted "$TARGET_DEVICE" --script --align optimal mkpart primary ${lvm_start}MiB 100%

# Wait for kernel to re-read partition table
sleep 2
partprobe "$TARGET_DEVICE"
sleep 1

echo "Partitioning complete. Setting up LUKS and LVM on ${TARGET_DEVICE}3..."
# Encrypt the LVM partition
echo "You will be prompted to enter a passphrase for disk encryption."
cryptsetup luksFormat "${TARGET_DEVICE}3"
cryptsetup open "${TARGET_DEVICE}3" cryptlvm

# Create LVM
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate -L "$root_size" vg0 -n root
lvcreate -l 100%FREE vg0 -n home

echo
echo "=========================================="
echo "LVM setup complete. Partitions:"
echo "- EFI:  ${TARGET_DEVICE}1 (${efi_size}MiB, fat32)"
echo "- Boot: ${TARGET_DEVICE}2 (${boot_size}MiB, ext4)"
echo "- Root: /dev/vg0/root ($root_size)"
echo "- Home: /dev/vg0/home (remaining space)"
echo "=========================================="
echo
echo "Partition layout:"
lsblk "$TARGET_DEVICE"
echo
echo "Format partitions with:"
echo "  mkfs.fat -F32 ${TARGET_DEVICE}1"
echo "  mkfs.ext4 ${TARGET_DEVICE}2"
echo "  mkfs.btrfs /dev/vg0/root  # or mkfs.ext4"
echo "  mkfs.ext4 /dev/vg0/home"