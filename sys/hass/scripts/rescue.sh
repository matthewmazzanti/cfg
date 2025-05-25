#!/usr/bin/env bash
set -xeu

KEYDEV="/dev/disk/by-path/pci-0000:00:14.0-usb-0:1:1.0-scsi-0:0:0:0"
ROOTDEV="/dev/disk/by-path/pci-0000:02:00.0-nvme-1"
part="$ROOTDEV-part/by-partlabel"

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
