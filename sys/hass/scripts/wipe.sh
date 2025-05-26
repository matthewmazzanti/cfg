#!/usr/bin/env bash
set -xeuo pipefail

KEYDEV="/dev/disk/by-id/usb-USB_SanDisk_3.2Gen1_010120f1fc6b4bb4ab4d7391d2fdf545bb3e6e6143450208f305b9fd806943b3e4e900000000000000000000f833a26f001c4900835581072a33742e-0:0"
ROOTDEV="/dev/disk/by-path/pci-0000:02:00.0-nvme-1"
part="$ROOTDEV-part/by-partlabel"

read -p "Wipe all drives?  " res
if [[ "$res" != "yes" ]]; then exit 1; fi

# Secure wipe, for final run
dd if=/dev/urandom of="$KEYDEV" bs=4K status=progress
dd if=/dev/urandom of="$ROOTDEV" bs=4K status=progress
blkdiscard -f "$ROOTDEV"
