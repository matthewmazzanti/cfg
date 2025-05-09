#!/usr/bin/env bash
set -xeuo pipefail

DISK="/dev/disk/by-path/pci-0000:02:00.0-nvme-1"
part="$DISK-part/by-partlabel"

# Open and mount
cryptsetup open \
    --type=plain \
    --cipher=aes-xts-plain64 \
    --key-size=256 \
    --key-file=/dev/urandom \
    "$part/swap" swap-crypt
mkswap --label swap /dev/mapper/swap-crypt

swapon /dev/mapper/swap-crypt
mkdir --parents /mnt
mount -t zfs root-pool /mnt
mkdir --parents /mnt/boot
mount "$part/ESP" /mnt/boot
