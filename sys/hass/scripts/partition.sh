#!/usr/bin/env bash
set -xeuo pipefail

KEYDEV="/dev/disk/by-id/usb-USB_SanDisk_3.2Gen1_010120f1fc6b4bb4ab4d7391d2fdf545bb3e6e6143450208f305b9fd806943b3e4e900000000000000000000f833a26f001c4900835581072a33742e-0:0"
ROOTDEV="/dev/disk/by-path/pci-0000:02:00.0-nvme-1"
part="$ROOTDEV-part/by-partlabel"

# Clean up $KEYDEV
umount /key-dev || true
wipefs --all "$ROOTDEV" || true

# Clean up $ROOTDEV
umount /mnt/boot || true
umount /mnt/nix || true
umount /mnt/persist || true
umount /mnt/home || true
umount /mnt || true
swapoff /dev/mapper/swap-crypt || true
cryptsetup luksClose swap-crypt || true
zpool destroy root-pool || true
cryptsetup luksClose root-crypt || true
wipefs --all "$KEYDEV" || true

# Create partition for primary disk
sgdisk \
    --clear \
    --new=0:0:+10G --typecode=0:EF00 --change-name=0:ESP \
    --new=0:0:+16G --typecode=0:8200 --change-name=0:swap \
    --new=0:0:0 --typecode=0:8300 --change-name=0:root \
    "$ROOTDEV"

# Wait for partitions
while [ ! -e "$part/ESP" ] || [ ! -e "$part/swap" ] || [ ! -e "$part/root" ]; do
    sleep 1
    echo "Waiting for partitions"
done

# Open and mount
cryptsetup open \
    --type=plain \
    --cipher=aes-xts-plain64 \
    --key-size=256 \
    --key-file=/dev/urandom \
    "$part/swap" swap-crypt

# Create Keyfile
mkfs.ext4 -L key "$KEYDEV"
mount -p -t ext4 -o noatime "$KEYDEV" /key-dev
echo "hass" > /key-dev/system
chmod 400 /key-dev/system
touch /key-dev/key-file
chmod 400 /key-dev/key-file
head -c256 < /dev/urandom | base64 > /key-dev/key-file

# Create luks filesystem on root partition
cryptsetup luksFormat --type=luks2 --key-file=/key-dev/key-file "$part/root"
cryptsetup luksAddKey --key-file=/key-dev/key-file --new-key-slot=31 "$part/root"
until cryptsetup open --key-file=/key-dev/key-file "$part/root" root-crypt; do
    echo "Try again"
done

# Create esp partition
mkfs.fat -F 32 -n ESP "$part/ESP"

# Create swap
mkswap --label swap /dev/mapper/swap-crypt

# Create zfs/impermanence filesystems
zpool create -f \
    -o ashift=9 \
    -O compression=lz4 \
    -O atime=off \
    -O xattr=sa \
    -O acltype=posixacl \
    -O mountpoint=none \
    root-pool /dev/mapper/root-crypt

zfs create -o mountpoint=none root-pool/local
zfs create -o mountpoint=none root-pool/state
zfs create -o mountpoint=legacy root-pool/local/root
zfs create -o mountpoint=legacy root-pool/local/nix
zfs create -o mountpoint=legacy root-pool/state/persist
zfs create -o mountpoint=legacy root-pool/state/home
zfs snapshot root-pool/local/root@blank

# Mount all filesystems
swapon /dev/mapper/swap-crypt
mount -p -t zfs -o noatime root-pool/local/root /mnt
mount -p -t vfat -o noatime "$part/ESP" /mnt/boot
mount -p -t zfs -o noatime root-pool/local/nix /mnt/nix
mount -p -t zfs -o noatime root-pool/state/persist /mnt/persist
mount -p -t zfs -o noatime root-pool/state/home /mnt/home

# Print filesystem ids
cat <<EOF

===Devices===
root /dev/disk/by-uuid/$(blkid --match-tag UUID --output value "$part/root")
key  /key-file:UUID=$(blkid --match-tag UUID --output value "$KEYDEV")
swap /dev/disk/by-partuuid/$(blkid --match-tag PARTUUID --output value "$part/swap")
boot /dev/disk/by-uuid/$(blkid --match-tag UUID --output value "$part/ESP")
EOF
