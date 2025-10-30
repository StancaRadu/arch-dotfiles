echo
echo "Available disk devices:"
echo "-----------------------"
lsblk -pn -o NAME,MODEL,SIZE,TYPE,MOUNTPOINT | sed 's/^/  /'
echo "-----------------------"
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