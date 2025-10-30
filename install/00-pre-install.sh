#!/bin/bash

CONFIG_FILE="install.conf"

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
    if [[ -z "$input" ]]; then
      eval "$var_name='$current_value'"
    else
      eval "$var_name='$input'"
    fi
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
  read -r -p "Configuration file found. Use values from $CONFIG_FILE? [Y/n]: " use_conf
  case "${use_conf,,}" in
    n|no)
      USE_CONFIG=false
      ;;
    *)
      USE_CONFIG=true
      load_config
      echo "Using configuration:"
      echo "  EFI Size:  ${EFI_SIZE}MiB"
      echo "  Boot Size: ${BOOT_SIZE}MiB"
      echo "  Root Size: ${ROOT_SIZE}"
      echo
      ;;
  esac
fi

# Get partition size configuration only if not using config
if [[ "$USE_CONFIG" == false ]]; then
  echo "Partition Size Configuration"
  echo "----------------------------"
  prompt_value "EFI partition size in MiB" "512" "EFI_SIZE"
  prompt_value "Boot partition size in MiB" "1024" "BOOT_SIZE"
  prompt_value "Root LV size (e.g., 50G or 51200M)" "50G" "ROOT_SIZE"
  echo
else
  echo "No configuration file found. You will be prompted for values."
  echo "Partition Size Configuration"
  echo "----------------------------"
  prompt_value "EFI partition size in MiB" "512" "EFI_SIZE"
  prompt_value "Boot partition size in MiB" "1024" "BOOT_SIZE"
  prompt_value "Root LV size (e.g., 50G or 51200M)" "50G" "ROOT_SIZE"
  echo
fi

# Always prompt for disk selection
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

# Wipe any existing partition table and signatures
wipefs -a "$TARGET_DEVICE" 2>/dev/null

# Calculate partition boundaries in MiB (ensures 1MiB alignment)
efi_start=1
efi_end=$((efi_start + EFI_SIZE))
boot_start=$efi_end
boot_end=$((boot_start + BOOT_SIZE))
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
# Always prompt for encryption password
echo "You will be prompted to enter a passphrase for disk encryption."
cryptsetup luksFormat "${TARGET_DEVICE}3"
cryptsetup open "${TARGET_DEVICE}3" cryptlvm

# Create LVM
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate -L "$ROOT_SIZE" vg0 -n root
lvcreate -l 100%FREE vg0 -n home

echo
echo "=========================================="
echo "LVM setup complete. Partitions:"
echo "- EFI:  ${TARGET_DEVICE}1 (${EFI_SIZE}MiB, fat32)"
echo "- Boot: ${TARGET_DEVICE}2 (${BOOT_SIZE}MiB, ext4)"
echo "- Root: /dev/vg0/root ($ROOT_SIZE)"
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

# Offer to save configuration
echo
read -r -p "Save partition sizes to $CONFIG_FILE for future use? [Y/n]: " save_conf
case "${save_conf,,}" in
  n|no)
    echo "Configuration not saved."
    ;;
  *)
    cat > "$CONFIG_FILE" << EOF
# Arch Linux Installation Configuration
# Edit these values as needed

# Partition sizes
EFI_SIZE=$EFI_SIZE
BOOT_SIZE=$BOOT_SIZE
ROOT_SIZE=$ROOT_SIZE
EOF
    echo "Configuration saved to $CONFIG_FILE"
    ;;
esac