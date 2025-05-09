#!/usr/bin/env bash
set -xeuo pipefail

DISK="/dev/disk/by-path/pci-0000:02:00.0-nvme-1"
part="$DISK-part/by-partlabel"

umount /mnt/boot || true
umount /mnt || true
swapoff /dev/mapper/swap-crypt || true
cryptsetup luksClose swap-crypt || true
zpool destroy root-pool || true
cryptsetup luksClose root-crypt || true

wipefs --all "$DISK"

sgdisk \
    --clear \
    --new=0:0:+10G --typecode=0:EF00 --change-name=0:ESP \
    --new=0:0:+16G --typecode=0:8200 --change-name=0:swap \
    --new=0:0:0 --typecode=0:8300 --change-name=0:root \
    "$DISK"

while [ ! -e "$part/ESP" ] || [ ! -e "$part/swap" ] || [ ! -e "$part/root" ]; do
    sleep 1
    echo "Waiting for partitions"
done

mkfs.fat -F 32 -n ESP "$part/ESP"

cryptsetup luksFormat --type=luks2 "$part/root"
cryptsetup open --type=luks2 "$part/root" root-crypt

zpool create -f \
    -o ashift=9 \
    -O compression=lz4 \
    -O atime=off \
    -O xattr=sa \
    -O acltype=posixacl \
    -O mountpoint=legacy \
    root-pool /dev/mapper/root-crypt
