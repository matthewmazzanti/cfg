#!/usr/bin/env bash
set -xeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../lib.sh"

passfile="$(get_passfile)"
trap 'rm -f "$passfile"' EXIT INT TERM

DEV="$by_id/usb-Samsung_Flash_Drive_0358123090004561-0:0"
ESP_PART="77fcf4e6-f15f-43a6-a3c5-b30fdfd9a39c"
ESP_FS="F716-67B8"
ROOT_PART="807c816a-cec5-4e2a-b7e1-e3034af7b6c7"
ROOT_CRYPT="90581c5c-2e2b-4c0e-81fe-1310536bd256"
ROOT_FS="f56ebe71-95cc-4e1c-b532-ffb24db99cb9"

# Clean up $DEV
umount -R /mnt || true
cryptsetup luksClose "$ROOT_CRYPT" || true
wipe_root_part "$DEV"

# Create partition for primary disk
sgdisk \
    --new=1:0:+1G \
    --typecode=1:EF00 \
    --change-name=1:ESPLIVE \
    --partition-guid=1:"$ESP_PART" \
    --new=2:0:0 \
    --typecode=2:8300 \
    --change-name=2:root-live \
    --partition-guid=2:"$ROOT_PART" \
    "$DEV"

blockdev --rereadpt "$DEV"
udevadm settle --timeout=10
wait_all_exist "$by_partuuid/$ESP_PART" "$by_partuuid/$ROOT_PART"

# Encrypt root filesystem
cryptsetup luksFormat \
    --type=luks2 \
    --cipher=aes-xts-plain64 \
    --key-size=512 \
    --pbkdf=argon2id \
    --uuid="$ROOT_CRYPT" \
    --key-file "$passfile" \
    "$by_partuuid/$ROOT_PART"

cryptsetup open \
    --persistent \
    --perf-no_read_workqueue \
    --perf-no_write_workqueue \
    --key-file "$passfile" \
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
mount \
    -t ext4 \
    -o noatime,nodiratime \
    "$by_uuid/$ROOT_FS" /mnt

mkdir -p /mnt/boot
mount \
    -t vfat \
    -o noatime,nodiratime,fmask=0022,dmask=0022 \
    "$by_uuid/$ESP_FS" /mnt/boot
