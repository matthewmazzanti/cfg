#!/usr/bin/env bash
set -xeuo pipefail

KEYDEV="/dev/disk/by-id/usb-USB_SanDisk_3.2Gen1_010120f1fc6b4bb4ab4d7391d2fdf545bb3e6e6143450208f305b9fd806943b3e4e900000000000000000000f833a26f001c4900835581072a33742e-0:0"
ROOTDEV="/dev/disk/by-path/pci-0000:02:00.0-nvme-1"

mkdir --parents /key-dev
mount "$KEYDEV" /key-dev

cryptsetup open --key-file=/key-dev/key-file "$part/root" root-crypt

mkdir --parents /mnt
zpool import -f root-pool
mount -t zfs root-pool/local/root /mnt
mkdir --parents /mnt/boot /mnt/nix /mnt/persist /mnt/home
mount "$part/ESP" /mnt/boot
mount -t zfs root-pool/local/nix /mnt/nix
mount -t zfs root-pool/state/persist /mnt/persist
mount -t zfs root-pool/state/home /mnt/home
