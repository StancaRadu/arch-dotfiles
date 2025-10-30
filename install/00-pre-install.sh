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
read -r -p "EFI partition size (default 1G): " efi_size
efi_size="${efi_size:-1G}"
read -r -p "Swap partition size (default none, e.g. 4G or leave blank): " swap_size
read -r -p "Root partition size (default remaining, e.g. 50G or leave blank for rest): " root_size

parted "$TARGET_DEVICE" -- mklabel gpt
start=1MiB
parted "$TARGET_DEVICE" -- mkpart primary fat32 "$start" "$efi_size"
parted "$TARGET_DEVICE" -- set 1 esp on
start="$efi_size"

if [[ -n "$swap_size" ]]; then
  end_swap="$((start + swap_size))"
  parted "$TARGET_DEVICE" -- mkpart primary linux-swap "$start" "$end_swap"
  start="$end_swap"
fi

if [[ -n "$root_size" ]]; then
  end_root="$((start + root_size))"
  parted "$TARGET_DEVICE" -- mkpart primary btrfs "$start" "$end_root"
else
  parted "$TARGET_DEVICE" -- mkpart primary btrfs "$start" 100%
fi

echo "Partitioning complete. Run 'lsblk $TARGET_DEVICE' to verify."