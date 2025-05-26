#!/usr/bin/env bash
set -xeuo pipefail

make_password() {
    user="$1"
    echo "Enter $1 password"
    touch "/mnt/persist/passwd/$user"
    chown root:shadow "/mnt/persist/passwd/$user"
    chmod 640 "/mnt/persist/passwd/$user"
    openssl passwd -6 > "/mnt/persist/passwd/$user"
}

# NOTE: Not actually run, just notes

if ! command -v git; then nix-env -iA nixpkgs.git; fi
if ! command -v sbctl; then nix-env -iA nixos.sbctl; fi
if ! command -v openssl; then nix-env -iA nixos.openssl; fi

if ! [ -e "$HOME/src/nix" ]; then
    mkdir --parents "$HOME/src/nix"
    git clone https://github.com/matthewmazzanti/cfg.git "$HOME/src/nix/cfg"
else
    git -C "$HOME/src/nix/cfg" pull
fi

mkdir --parents /mnt/persist/var/lib/sbctl /mnt/var/lib/sbctl
sbctl create-keys \
    --database-path /mnt/persist/var/lib/sbctl \
    --export /mnt/persist/var/lib/sbctl/keys
mount --bind /mnt/persist/var/lib/sbctl /mnt/var/lib/sbctl

nixos-install \
    --root /mnt \
    --no-channel-copy \
    --no-root-password \
    --flake "$HOME/src/nix/cfg#hass"

umount /mnt/var/lib/sbctl

mkdir --parents /mnt/persist/passwd
make_password "root"
make_password "mmazzanti"

ssh-keygen -A -f /mnt/persist
