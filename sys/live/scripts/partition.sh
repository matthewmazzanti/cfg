#!/usr/bin/env bash
set -xeuo pipefail

find_by_path() {
    local drive="$(readlink -f "$1")"
    for file in /dev/disk/by-path/*; do
        if [[ -L "$file" ]] && [[ "$(readlink -f "$file")" == "$drive" ]]; then
            echo "$file"
            return 0
        fi
    done

    return 1
}

find_uuid() {
    blkid --match-tag UUID --output value "$1"
}

ROOTDEV="$(find_by_path /dev/disk/by-id/usb-Samsung_Flash_Drive_0358123090004561-0:0)"
part="$ROOTDEV-part/by-partlabel"

# Clean up $ROOTDEV
umount /mnt/boot || true
umount /mnt || true
cryptsetup luksClose root-live-crypt || true
wipefs --all "$ROOTDEV" || true

# Create partition for primary disk
sgdisk \
    --clear \
    --new=0:0:+1G --typecode=0:EF00 --change-name=0:ESPLIVE \
    --new=0:0:0 --typecode=0:8300 --change-name=0:root-live \
    "$ROOTDEV"

# Wait for partitions
while [ ! -e "$part/ESPLIVE" ] || [ ! -e "$part/root-live" ]; do
    sleep 1
    echo "Waiting for partitions"
done

# Encrypt root filesystem
until cryptsetup luksFormat --type=luks2 "$part/root-live"; do
    echo "Try again"
done
until cryptsetup luksOpen --type=luks2 "$part/root-live" root-live-crypt; do
    echo "Try again"
done

# Make filesystems
mkfs -t ext4 -L root-live "/dev/mapper/root-live-crypt"
mkfs -t fat -F 32 -n ESPLIVE "$part/ESPLIVE"

# Mount filesystems
mkdir -p /mnt
mount -t ext4 -o noatime "/dev/mapper/root-live-crypt" /mnt
mkdir -p /mnt/boot
mount -t vfat -o noatime "$part/ESPLIVE" /mnt/boot

# Print filesystem ids
cat <<EOF

===Devices===
root-live       /dev/disk/by-uuid/$(find_uuid "$part/root-live")
root-live-crypt /dev/disk/by-uuid/$(find_uuid "/dev/mapper/root-live-crypt")
ESPLIVE         /dev/disk/by-uuid/$(find_uuid "$part/ESPLIVE")
EOF
