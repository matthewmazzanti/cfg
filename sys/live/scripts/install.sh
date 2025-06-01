#!/usr/bin/env bash
set -xeuo pipefail

make_password() {
    user="$1"
    echo "Enter password for $1"
    mkdir -p /mnt/persist/passwd
    touch "/mnt/persist/passwd/$user"
    chown root:shadow "/mnt/persist/passwd/$user"
    chmod 640 "/mnt/persist/passwd/$user"
    until openssl passwd -6 > "/mnt/persist/passwd/$user"; do
        echo "Try again"
    done
}

if ! command -v git; then nix-env -iA nixpkgs.git; fi
if ! command -v sbctl; then nix-env -iA nixos.sbctl; fi
if ! command -v openssl; then nix-env -iA nixos.openssl; fi

if ! [ -e "$HOME/src/nix" ]; then
    mkdir -p "$HOME/src/nix"
    git clone https://github.com/matthewmazzanti/cfg.git "$HOME/src/nix/cfg"
else
    git -C "$HOME/src/nix/cfg" pull
fi

# Install nixos
nixos-install \
    --root /mnt \
    --no-channel-copy \
    --no-root-password \
    --flake "$HOME/src/nix/cfg#live"

# Create ssh host keys in persist
ssh-keygen -A -f /mnt/persist

# Create passwords
make_password "mmazzanti"
