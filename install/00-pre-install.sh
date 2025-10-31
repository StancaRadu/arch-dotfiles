#!/bin/bash

CONFIG_FILE="install.conf"

# Function to convert size to MiB
convert_to_mib() {
  local size="$1"
  local value="${size%[GMgm]}"
  local unit="${size: -1}"
  
  case "${unit^^}" in
    G) echo "$((value * 1024))" ;;
    M) echo "$value" ;;
    *) echo "$size" ;;  # Already a number
  esac
}

# Function to load config
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    echo "Configuration loaded from $CONFIG_FILE"
    return 0
  else
    echo "No configuration file found at $CONFIG_FILE"
    return 1
  fi
}

# Function to prompt for value with default
prompt_value() {
  local prompt_text="$1"
  local default_value="$2"
  local var_name="$3"
  local current_value="${!var_name}"
  
  if [[ -n "$current_value" ]]; then
    read -r -p "$prompt_text (current: $current_value, press Enter to keep): " input
    eval "$var_name='${input:-$current_value}'"
  else
    read -r -p "$prompt_text (default: $default_value): " input
    eval "$var_name='${input:-$default_value}'"
  fi
}

echo "==================================="
echo "Arch Linux Disk Partitioning Script"
echo "==================================="
echo

# Check if config file exists and ask if user wants to use it
USE_CONFIG=false
if [[ -f "$CONFIG_FILE" ]]; then
  read -r -p "Use config from $CONFIG_FILE? [Y/n]: " use_conf
  if [[ ! "${use_conf,,}" =~ ^n ]]; then
    USE_CONFIG=true
    load_config
    echo "EFI: $EFI_SIZE | Boot: $BOOT_SIZE | Root: $ROOT_SIZE | Home: ${HOME_SIZE:-remaining}"
    echo
  fi
fi

# Get partition size configuration only if not using config
if [[ "$USE_CONFIG" == false ]]; then
  echo "Partition sizes (use G for GiB, M for MiB, e.g., 512M or 50G)"
  echo "---------------------------------------------------------------"
  prompt_value "EFI partition size" "512M" "EFI_SIZE"
  prompt_value "Boot partition size" "1G" "BOOT_SIZE"
  prompt_value "Root volume size" "8G" "ROOT_SIZE"
  prompt_value "Home volume size (leave empty for remaining space)" "" "HOME_SIZE"
  echo
fi

# Always prompt for disk selection
echo "Available disks:"
lsblk -pn -o NAME,MODEL,SIZE,TYPE,MOUNTPOINT | grep disk | sed 's/^/  /'
echo
while true; do
  read -r -p "Enter device (e.g., /dev/sda): " TARGET_DEVICE
  [[ -z "$TARGET_DEVICE" ]] && continue
  [[ ! "$TARGET_DEVICE" =~ ^/dev/ ]] && echo "Must start with /dev/" && continue
  [[ ! -b "$TARGET_DEVICE" ]] && echo "Not a valid block device" && continue
  break
done

echo
echo "==============================================="
echo "  FINAL WARNING: $TARGET_DEVICE WILL BE WIPED"
echo "==============================================="
echo
echo "EFI: $EFI_SIZE | Boot: $BOOT_SIZE | Root: $ROOT_SIZE | Home: ${HOME_SIZE:-remaining}"
read -r -p "Type 'yes' to continue: " confirm
[[ "$confirm" != "yes" ]] && echo "Aborted." && exit 1

# Convert sizes to MiB
EFI_MIB=$(convert_to_mib "$EFI_SIZE")
BOOT_MIB=$(convert_to_mib "$BOOT_SIZE")

# Wipe disk
echo "Wiping $TARGET_DEVICE..."
wipefs -a "$TARGET_DEVICE" 2>/dev/null

# Calculate partition boundaries
efi_start=1
efi_end=$((efi_start + EFI_MIB))
boot_start=$efi_end
boot_end=$((boot_start + BOOT_MIB))
lvm_start=$boot_end

# Create partitions
echo "Creating partitions..."
parted "$TARGET_DEVICE" --script --align optimal mklabel gpt
parted "$TARGET_DEVICE" --script --align optimal mkpart primary fat32 ${efi_start}MiB ${efi_end}MiB
parted "$TARGET_DEVICE" --script set 1 esp on
parted "$TARGET_DEVICE" --script --align optimal mkpart primary ext4 ${boot_start}MiB ${boot_end}MiB
parted "$TARGET_DEVICE" --script --align optimal mkpart primary ${lvm_start}MiB 100%

sleep 2
partprobe "$TARGET_DEVICE"
sleep 1

# Setup LUKS
echo "Setting up disk encryption..."
cryptsetup luksFormat "${TARGET_DEVICE}3"
cryptsetup open "${TARGET_DEVICE}3" cryptlvm

# Create LVM
echo "Creating logical volumes..."
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate -L "$ROOT_SIZE" vg0 -n root

if [[ -n "$HOME_SIZE" ]]; then
  lvcreate -L "$HOME_SIZE" vg0 -n home
else
  lvcreate -l 100%FREE vg0 -n home
fi
vgscan
vgscan -ay

echo
echo "==================="
echo "  Setup complete!"
echo "=================="
lsblk "$TARGET_DEVICE"

mkfs.fat -F32 "${TARGET_DEVICE}1"         # EFI partition (FAT32 required for UEFI)
mkfs.ext4 "${TARGET_DEVICE}2"             # Boot partition
mkfs.ext4 /dev/vg0/root                   # Root logical volume
mkfs.ext4 /dev/vg0/home                   # Home logical volume

mount /dev/vg0/root /mnt
mkdir /mnt/boot
mount "${TARGET_DEVICE}2" /mnt/boot
mkdir /mnt/home
mount /dev/vg0/home /mnt/home

export TARGET_DEVICE
sed -i "s|^TARGET_DEVICE=.*|TARGET_DEVICE=\"$TARGET_DEVICE\"|" /root/arch-dotfiles/install.conf

bash ./01-base-install.sh