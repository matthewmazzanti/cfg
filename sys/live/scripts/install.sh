#!/usr/bin/env bash
set -xeuo pipefail

if ! command -v git; then nix-env -iA nixpkgs.git; fi

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
