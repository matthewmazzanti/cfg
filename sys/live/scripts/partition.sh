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
ESP_PART="77fcf4e6-f15f-43a6-a3c5-b30fdfd9a39c"
ESP_FS="f71667b8"
ROOT_PART="807c816a-cec5-4e2a-b7e1-e3034af7b6c7"
ROOT_CRYPT="90581c5c-2e2b-4c0e-81fe-1310536bd256"
ROOT_FS="f56ebe71-95cc-4e1c-b532-ffb24db99cb9"


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
while [[ ! -e "$by_partuuid/$ESP_PART" || ! -e "$by_partuuid/$ROOT_PART" ]]; do
    sleep 1
    echo "Waiting for partitions"
done

# Encrypt root filesystem
cryptsetup luksFormat \
    --type=luks2 \
    --uuid="$ROOT_CRYPT" \
    "$by_partuuid/$ROOT_PART" \
    --key-file "-" <<<"$PASSWORD"

cryptsetup luksOpen \
    --type=luks2 \
    --persistent \
    --allow-discards \
    --perf-no_read_workqueue \
    --perf-no_write_workqueue \
    "$by_partuuid/$ROOT_PART" \
    root-live-crypt \
    --key-file "-" <<<"$PASSWORD"

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
