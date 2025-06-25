#!/usr/bin/env bash
set -xeuo pipefail

make_password() {
    user="$1"
    mkdir -p /mnt/persist/passwd
    touch "/mnt/persist/passwd/$user"
    chown root:shadow "/mnt/persist/passwd/$user"
    chmod 640 "/mnt/persist/passwd/$user"

    echo "Enter password for $1"
    until openssl passwd -6 > "/mnt/persist/passwd/$user"; do
        echo "Try again"
    done
}

# Create sbctl keys
mkdir -p /mnt/persist/var/lib/sbctl /mnt/var/lib/sbctl
sbctl create-keys \
    --database-path /mnt/persist/var/lib/sbctl \
    --export /mnt/persist/var/lib/sbctl
# Mount into chroot
mount --bind /mnt/persist/var/lib/sbctl /mnt/var/lib/sbctl

# Install nixos
nixos-install \
    --root /mnt \
    --no-channel-copy \
    --no-root-password \
    --flake "$HOME/src/nix/cfg#hass"

# Unmount sbctl from chroot
umount /mnt/var/lib/sbctl

# Create ssh host keys in persist
ssh-keygen -A -f /mnt/persist

# Create passwords
make_password "mmazzanti"
