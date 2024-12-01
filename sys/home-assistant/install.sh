#!/usr/bin/env bash
set -euxo pipefail

if ! command -v git; then
    nix-env -iA nixos.git
fi

start="0%"
firmware="1GB"
swap="4GB"
system="home-assistant"

disk="/dev/disk/by-id/usb-SSI_M.2_NVME_SSD_00000000000000000000-0:0"
nixos_part="$disk-part1"
swap_part="$disk-part2"
firmware_part="$disk-part3"

umount /mnt/boot/firmware || true
umount /mnt/boot || true
umount /mnt || true
swapoff "$swap_part" || true
wipefs -a "$disk"*

# Partition disk
# Layout: 512MB ESP, 4GB swap, rest filled with ext4 root
parted "$disk" -- mklabel gpt
parted "$disk" -- mkpart primary "$firmware" "-$swap"
parted "$disk" -- set 1 boot on
parted "$disk" -- mkpart swap linux-swap "-$swap" 100%
parted "$disk" -- mkpart FIRMWARE fat32 "$start" "$firmware"

# Wait for entries to show up
sleep 1

# Setup partitions
# Format main drive
mkfs.ext4 -L nixos "$nixos_part"
# Setup swap
mkswap --label swap "$swap_part"
# Format firmware partition
mkfs.fat -F 32 -n FIRMWARE "$firmware_part"

# Mount filesystems
swapon "$swap_part"
mount "$nixos_part" /mnt
mkdir --parents /mnt/boot/firmware
mount "$firmware_part" /mnt/boot/firmware

exit

# Clone git config
git clone \
    --branch=integrate-old \
    https://github.com/matthewmazzanti/cfg.git \
    /mnt/etc/nixos

nixos-generate-config \
    --root /mnt \
    --show-hardware-config \
    > "/mnt/etc/nixos/sys/$system/hardware.nix"

nixos-install --root /mnt --flake "/mnt/etc/nixos#$system"
