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
# Sector size: 512B
parted "$disk" -- mklabel gpt
parted "$disk" -- mkpart FIRMWARE fat32 "2048s" "206847s" # 100MiB + 2048s
parted "$disk" -- mkpart swap linux-swap "206848s" "8595455s" # 4GiB + 100MiB + 2048s
parted "$disk" -- mkpart primary "8595456s" "100%"
parted "$disk" -- set 3 esp on

# Wait for entries to show up
sleep 1

# Setup partitions
mkfs.fat -F 32 -n FIRMWARE "$firmware_part"
mkswap --label swap "$swap_part"
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

# Bootstrap installer script, workaround for installing firmware
pushd /mnt/etc/nixos/sys/home-assistant
nix-build \
    --expr 'with import <nixpkgs> {}; (callPackage ./install-firmware.nix {}).installScript' \
    --out-link /tmp/firmware-installer
popd

# Install onto drive
system="home-assistant"
nixos-generate-config \
    --root /mnt \
    --show-hardware-config \
    > "/mnt/etc/nixos/sys/$system/hardware.nix"
/tmp/firmware-installer/bin/install-rpi-firmware /mnt/boot/firmware
nixos-install --root /mnt --flake "/mnt/etc/nixos#$system"

# nixos-enter --root /mnt -c '/nix/var/nix/profiles/system/sw/bin/passwd'
# nixos-enter --root /mnt -c '/nix/var/nix/profiles/system/sw/bin/passwd mmazzanti'
