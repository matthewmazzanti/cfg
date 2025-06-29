#!/usr/bin/env bash
set -xeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../lib.sh"

HOST="server"

# Create sbctl keys
mkdir -p /mnt/persist/var/lib/sbctl /mnt/var/lib/sbctl
mount --bind /mnt/persist/var/lib/sbctl /mnt/var/lib/sbctl

# Install nixos
nixos-install \
    --root /mnt \
    --no-channel-copy \
    --no-root-password \
    --no-bootloader \
    --flake "$SUDO_HOME/src/nix/cfg#$HOST"

# Install sbctl keys, needed for bootloader install
nixos-enter -- bash <<'EOF'
sbctl create-keys
ssh-keygen -A -f /persist
EOF

# Install Bootloader
nixos-install \
    --root /mnt \
    --no-channel-copy \
    --no-root-password \
    --flake "$SUDO_HOME/src/nix/cfg#$HOST"

# Cleanup /nix
nixos-enter -- bash <<'EOF'
nix-collect-garbage --delete-old
nix-store --optimise
EOF

# Unmount sbctl from chroot
umount /mnt/var/lib/sbctl

# Create passwords
install_user_password "mmazzanti"
