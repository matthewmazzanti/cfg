#!/usr/bin/env bash
set -euo pipefail

if ! command -v git; then
    nix-env -iA nixpkgs.git
fi

disk="/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_1TB_S7M3NL0X933009L"
boot_part="/dev/disk/by-partlabel/ESP"
swap_part="/dev/disk/by-partlabel/swap"
root_part="/dev/disk/by-partlabel/root"

umount /mnt/boot || true
umount /mnt || true
swapoff "$swap_part" || true
wipefs -a "$disk"*

# Partition disk
# Layout: 4GB ESP, 8GB swap, rest filled with ext4 root
# Sector size: 512B
parted "$disk" -- mklabel gpt
parted "$disk" -- mkpart ESP fat32 "2048s" "8390655s" # 4GiB ESP partition
parted "$disk" -- set 1 boot on
parted "$disk" -- mkpart swap linux-swap "8390656s" "25167871s" # 8GiB Swap partition
parted "$disk" -- mkpart root "25167872s" "100%"

# Wait for by-label entries to show up
while [[ ! -e "$root_part" ]]; do
    sleep 1
done

# Enable Swap
mkswap --label swap "$swap_part"
swapon "$swap_part"

# Set up root partition
mkfs.ext4 -L root "$root_part"
mount "$root_part" /mnt

# Setup boot partition
mkfs.fat -F 32 -n ESP "$boot_part"
mkdir --parents /mnt/boot
mount "$boot_part" /mnt/boot

# Clone git config
git clone \
    --branch=integrate-old \
    https://github.com/matthewmazzanti/cfg.git \
    /mnt/etc/nixos

system="home-assistant"
nixos-install --root /mnt --flake "/mnt/etc/nixos#$system"
