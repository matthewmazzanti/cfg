#!/usr/bin/env bash
set -xeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../lib.sh"

get_password

DEV="$by_id/usb-Samsung_Flash_Drive_0358123090004561-0:0"
ESP_PART="77fcf4e6-f15f-43a6-a3c5-b30fdfd9a39c"
ESP_FS="F716-67B8"
ROOT_PART="807c816a-cec5-4e2a-b7e1-e3034af7b6c7"
ROOT_CRYPT="90581c5c-2e2b-4c0e-81fe-1310536bd256"
ROOT_FS="f56ebe71-95cc-4e1c-b532-ffb24db99cb9"

# Clean up $DEV
umount -R /mnt || true
cryptsetup luksClose "$ROOT_CRYPT" || true
wipefs --all "$DEV" || true

# Create partition for primary disk
sgdisk \
    --clear \
    --new=0:0:+1G --typecode=0:EF00 --change-name=0:ESPLIVE \
    --partition-guid=0:"$ESP_PART" \
    --new=0:0:0 --typecode=0:8300 --change-name=0:root-live \
    --partition-guid=0:"$ROOT_PART" \
    "$DEV"

udevadm settle --timeout=10 --exit-if-exists="$by_partuuid/$ESP_PART"
udevadm settle --timeout=10 --exit-if-exists="$by_partuuid/$ROOT_PART"

# Encrypt root filesystem
cryptsetup luksFormat \
    --type=luks2 \
    --uuid="$ROOT_CRYPT" \
    --key-file <(tr -d '\n' <<<"$PASSWORD") \
    "$by_partuuid/$ROOT_PART"

cryptsetup open \
    --persistent \
    --perf-no_read_workqueue \
    --perf-no_write_workqueue \
    --key-file <(tr -d '\n' <<<"$PASSWORD") \
    "$by_partuuid/$ROOT_PART" \
    "$ROOT_CRYPT"

# Make filesystems
mkfs.ext4 \
    -L root-live \
    -U "$ROOT_FS" \
    "$mapper/$ROOT_CRYPT"

mkfs.fat \
    -F 32 \
    -n ESPLIVE \
    -i "$(tr -d '-' <<<"$ESP_FS")" \
    "$by_partuuid/$ESP_PART"

# Mount filesystems
mkdir -p /mnt
mount -t ext4 -o noatime "$by_uuid/$ROOT_FS" /mnt
mkdir -p /mnt/boot
mount -t vfat \
    -o noatime -o fmask=0022 -o dmask=0022 \
    "$by_uuid/$ESP_FS" /mnt/boot
