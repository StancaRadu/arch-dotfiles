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
# Ask for partition sizes (with defaults)
read -r -p "EFI partition size (default 512M): " efi_size
efi_size="${efi_size:-512M}"
read -r -p "Boot partition size (default 1G): " boot_size
boot_size="${boot_size:-1G}"
read -r -p "Root LV size (default 50G, remaining for home): " root_size
root_size="${root_size:-50G}"

# Partition with parted
parted "$TARGET_DEVICE" --script mklabel gpt
start=1MiB
parted "$TARGET_DEVICE" --script mkpart primary fat32 "$start" "$efi_size"
parted "$TARGET_DEVICE" --script set 1 esp on
start="$efi_size"
end_boot="$((start + boot_size))"
parted "$TARGET_DEVICE" --script mkpart primary ext4 "$start" "$end_boot"
start="$end_boot"
parted "$TARGET_DEVICE" --script mkpart primary ext4 "$start" 100%

echo "Partitioning complete. Setting up LUKS and LVM on ${TARGET_DEVICE}3..."
# Encrypt the LVM partition (assuming /dev/sda3)
cryptsetup luksFormat "${TARGET_DEVICE}3"
cryptsetup open "${TARGET_DEVICE}3" cryptlvm

# Create LVM
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate -L "$root_size" vg0 -n root
lvcreate -l 100%FREE vg0 -n home

echo "LVM setup complete. Partitions:"
echo "- EFI: ${TARGET_DEVICE}1 (fat32)"
echo "- Boot: ${TARGET_DEVICE}2 (ext4)"
echo "- Root: /dev/vg0/root (btrfs or ext4)"
echo "- Home: /dev/vg0/home (ext4)"
echo "Run 'lsblk' and format with mkfs commands as needed."