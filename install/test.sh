#!/bin/bash

CONFIG_FILE="arch-install.conf"

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

prompt_value "Enter target device (e.g., /dev/sda)" "/dev/sda" "TARGET_DEVICE"