#!/usr/bin/env bash
set -xeuo pipefail

by_id="/dev/disk/by-id"
by_uuid="/dev/disk/by-uuid"
by_partuuid="/dev/disk/by-partuuid"
by_path="/dev/disk/by-path"

get_password() {
    local password confirm_password

    while true; do
        read -rsp "Enter password: " password
        echo
        read -rsp "Confirm password: " confirm_password
        echo

        if [[ -z "$password" ]]; then
            echo "Password cannot be empty." >&2
        elif [[ "$password" != "$confirm_password" ]]; then
            echo "Passwords do not match. Please try again." >&2
        else
            break
        fi
    done

    PASSWORD="$password"
}

# Call the function
if get_password; then
    echo "Password has been securely read."
    # Use $PASSWORD as needed
else
    exit 1
fi

DEV="$by_id/usb-Samsung_Flash_Drive_0358123090004561-0:0"
ESP_PART="11cb24df-80bb-4e4b-bd22-1c64bbd6833a"
ESP_FS="2af7fb24"
ROOT_PART="63ee84c3-7612-4838-8487-38b82ff3df82"
ROOT_CRYPT="a8cfc593-d57c-4d46-9fbb-6b90982e5a02"
ROOT_FS="d8d1d6d8-4bb1-4505-80ea-cf9426864b8f"


# Clean up $DEV
umount -R /mnt || true
cryptsetup luksClose "$by_uuid/$ROOT_CRYPT" || true
wipefs --all "$DEV" || true

# Create partition for primary disk
sgdisk \
    --clear \
    --new=0:0:+1G --typecode=0:EF00 --change-name=0:ESPLIVE \
    --partition-guid=0:"$ESP_PART" \
    --new=0:0:0 --typecode=0:8300 --change-name=0:root-live \
    --partition-guid=0:"$ROOT_PART" \
    "$DEV"

# Wait for partitions
until [[ -e "$by_partuuid/$ESP_PART" && -e "$by_partuuid/$ROOT_PART" ]]; do
    sleep 1
    echo "Waiting for partitions"
done

# Encrypt root filesystem
cryptsetup luksFormat --type=luks2 \
    --uuid="$ROOT_CRYPT" \
    "$by_partuuid/$ROOT_PART" \
    <<<"$PASSWORD"

cryptsetup luksOpen --type=luks2 \
    --persistent \
    --allow-discards \
    --perf-no_read_workqueue \
    --perf-no_write_workqueue \
    "$by_partuuid/$ROOT_PART" \
    root-live-crypt \
    <<<"$PASSWORD"

# Make filesystems
mkfs.ext4 \
    -L root-live \
    -U "$ROOT_FS" \
    "$by_uuid/$ROOT_CRYPT"

mkfs.fat \
    -F 32 \
    -n ESPLIVE \
    -i "$ESP_FS" \
    "$by_partuuid/$ESP_PART"

# Mount filesystems
mkdir -p /mnt
mount -t ext4 -o noatime "$by_uuid/$ROOT_FS" /mnt
mkdir -p /mnt/boot
mount -t vfat -o noatime "$by_uuid/$ESP_FS" /mnt/boot
