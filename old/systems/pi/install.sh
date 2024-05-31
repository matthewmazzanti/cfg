#!/usr/bin/env bash
set -ex
start="65535s"
esp="1GB"
swap="4GB"
system="pi"

disk="/dev/sdb"
partlabel="/dev/disk/by-partlabel"
label="/dev/disk/by-label"

umount /mnt/boot || true
umount /mnt || true
swapoff "$partlabel/swap" || true
wipefs -a "$disk"*

# Partition disk
# Layout: 512MB ESP, 4GB swap, rest filled with ext4 root
parted "$disk" -- mklabel gpt
parted "$disk" -- mkpart primary "$esp" "-$swap"
parted "$disk" -- mkpart swap linux-swap "-$swap" 100%
parted "$disk" -- mkpart ESP fat32 "$start" "$esp"
parted "$disk" -- set 3 esp on

# Wait for by-partlabel entries to show up
sleep 1

# Format main drive
mkfs.ext4 -L nixos "$partlabel/primary"
# Setup swap
mkswap --label swap "$partlabel/swap"
swapon "$partlabel/swap"
# Format EFI partition
mkfs.fat -F 32 -n boot "$partlabel/ESP"

# Wait for by-label entries to show up
sleep 1

# Mount filesystems
mount "$label/nixos" /mnt
mkdir --parents /mnt/boot
mount "$label/boot" /mnt/boot

# Run the installation from git
# nix-env --install git
git clone \
    -c http.sslVerify=false \
    https://git.omega.xi/mmazzanti/nixos.git \
    /mnt/etc/nixos
nixos-generate-config \
    --root /mnt \
    --show-hardware-config \
    > "/mnt/etc/nixos/systems/$system/hardware-configuration.nix"
nixos-install --root /mnt --flake "/mnt/etc/nixos#$system"
