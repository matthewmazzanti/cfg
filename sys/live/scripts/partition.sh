#!/usr/bin/env bash
set -xeuo pipefail

find_uuid() {
    blkid --match-tag UUID --output value "$1"
}

ROOTDEV=""
part="$ROOTDEV-part/by-partlabel"

# Clean up $ROOTDEV
umount /mnt/boot || true
umount /mnt || true
cryptsetup luksClose root-crypt || true
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
cryptsetup luksFormat --type=luks2 "$part/root-live"
cryptsetup luksOpen --type=luks2 "$part/root-live" root-live-crypt

# Make filesystems
mkfs -t ext4 -L root-live "/dev/mapper/root-live-crypt"
mkfs -t fat -F 32 -n ESPLIVE "$part/ESPLIVE"

# Mount filesystems
mount -p -t ext4 -o noatime "/dev/mapper/root-live-crypt" /mnt
mount -p -t vfat -o noatime "$part/ESPLIVE" /mnt/boot

# Print filesystem ids
cat <<EOF

===Devices===
root-live       /dev/disk/by-uuid/$(find_uuid "$part/root-live")
root-live-crypt /dev/disk/by-uuid/$(find_uuid "/dev/mapper/root-live-crypt")
ESPLIVE         /dev/disk/by-uuid/$(find_uuid "$part/ESPLIVE")
EOF
