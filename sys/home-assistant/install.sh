#!/usr/bin/env bash
set -euxo pipefail

if ! command -v git; then
    nix-env -iA nixpkgs.git
fi

# Variables for disk reference. Use by ID to ensure correct disk
disk="/dev/disk/by-id/usb-SSI_M.2_NVME_SSD_00000000000000000000-0:0"
firmware_part="$disk-part1"
swap_part="$disk-part2"
nixos_part="$disk-part3"

umount /mnt/boot/firmware || true
umount /mnt/boot || true
umount /mnt || true
swapoff "$swap_part" || true
wipefs -a "$disk"*

# Partition disk
# Layout: 100MB firmware, 4GB swap, rest filled with ext4 root
firmware_offset="100MB"
swap_offset="4100MB"
parted "$disk" -- mklabel gpt
parted "$disk" -- mkpart FIRMWARE fat32 "0%" "$firmware_offset"
parted "$disk" -- mkpart swap linux-swap "$firmware_offset" "$swap_offset"
parted "$disk" -- mkpart primary "$swap_offset" "100%"
parted "$disk" -- set 3 boot on

# Wait for entries to show up
sleep 1

# Setup partitions
# Format firmware partition
mkfs.fat -F 32 -n FIRMWARE "$firmware_part"
# Setup swap
mkswap --label swap "$swap_part"
# Format main drive
mkfs.ext4 -L nixos "$nixos_part"

# Mount filesystems
swapon "$swap_part"
mount "$nixos_part" /mnt
mkdir --parents /mnt/boot/firmware
mount "$firmware_part" /mnt/boot/firmware

# Clone git config
git clone \
    --branch=integrate-old \
    https://github.com/matthewmazzanti/cfg.git \
    /mnt/etc/nixos

system="home-assistant"

nixos-generate-config \
    --root /mnt \
    --show-hardware-config \
    > "/mnt/etc/nixos/sys/$system/hardware.nix"

nixos-install --root /mnt --flake "/mnt/etc/nixos#$system"
