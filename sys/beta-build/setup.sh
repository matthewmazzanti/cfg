#!/usr/bin/env bash
set -ex
disk="/dev/vda"

function wait_for() {
    drive="$1"
    until [ -e "$drive" ]; do
        echo "Waiting for $drive to be ready..."
        sleep 1
    done
    echo "Device $drive ready"
}

# Partition disk
parted "$disk" -- mklabel gpt
parted "$disk" -- mkpart primary 512MiB 100%
parted "$disk" -- mkpart ESP fat32 1MiB 512MiB
parted "$disk" -- set 2 esp on

# Format main drive
partlabel="/dev/disk/by-partlabel"
wait_for "$partlabel/primary"
mkfs.ext4 -L nixos "$partlabel/primary"
mkfs.fat -F 32 -n boot "$partlabel/ESP"

# Mount filesystems
label="/dev/disk/by-label"
wait_for "$label/nixos"
mount "$label/nixos" /mnt
mkdir /mnt/boot
mount "$label/boot" /mnt/boot
