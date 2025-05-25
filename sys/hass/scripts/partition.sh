#!/usr/bin/env bash
set -xeuo pipefail

KEYDEV="/dev/disk/by-path/pci-0000:00:14.0-usb-0:1:1.0-scsi-0:0:0:0"
ROOTDEV="/dev/disk/by-path/pci-0000:02:00.0-nvme-1"
part="$ROOTDEV-part/by-partlabel"

# Clean up mounts/filesystems
umount /key-dev || true
umount /mnt/boot || true
umount /mnt || true
swapoff /dev/mapper/swap-crypt || true
cryptsetup luksClose swap-crypt || true
zpool destroy root-pool || true
cryptsetup luksClose root-crypt || true
wipefs --all "$KEYDEV"
wipefs --all "$ROOTDEV"

# Create partition for primary disk
sgdisk \
    --clear \
    --new=0:0:+10G --typecode=0:EF00 --change-name=0:ESP \
    --new=0:0:+16G --typecode=0:8200 --change-name=0:swap \
    --new=0:0:0 --typecode=0:8300 --change-name=0:root \
    "$ROOTDEV"


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
KEYFILE="/key-dev/key-file"
mkfs.ext4 -L key "$KEYDEV"
mkdir /key-dev
mount "$KEYDEV" /key-dev
echo "hass" > /key-dev/system
chmod 400 /key-dev/system
touch /key-dev/key-file
chmod 400 /key-dev/key-file
(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c256) > /key-dev/key-file

# Create luks filesystem on root partition
cryptsetup luksFormat --type=luks2 --key-file=/key-dev/key-file "$part/root"
cryptsetup luksAddKey --key-file=/key-dev/key-file --new-key-slot=31 "$part/root"
cryptsetup open --key-file=/key-dev/key-file "$part/root" root-crypt

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

zfs create -o mountpoint=none /local
zfs create -o mountpoint=none /state
zfs create -o mountpoint=legacy /local/root
zfs create -o mountpoint=legacy /local/nix
zfs create -o mountpoint=legacy /state/persist
zfs create -o mountpoint=legacy /state/home
zfs snapshot /local/root@blank

# Mount all filesystems
swapon /dev/mapper/swap-crypt
mkdir --parents /mnt
mkdir --parents /mnt/boot
mkdir --parents /mnt/nix
mkdir --parents /mnt/persist
mkdir --parents /mnt/home
mount -t zfs root-pool/local/root /mnt
mount "$part/ESP" /mnt/boot
mount -t zfs root-pool/local/nix /mnt/nix
mount -t zfs root-pool/state/persist /mnt/persist
mount -t zfs root-pool/state/home /mnt/home
