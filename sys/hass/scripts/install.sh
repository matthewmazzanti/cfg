#!/usr/bin/env bash
set -xeuo pipefail

# NOTE: Not actually run, just notes

if ! command -v git; then nix-env -iA nixpkgs.git; fi
if ! command -v sbctl; then nix-env -iA nixos.sbctl; fi

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
nixos-install --root /mnt --flake "$HOME/src/nix/cfg#hass"
umount /mnt/var/lib/sbctl
