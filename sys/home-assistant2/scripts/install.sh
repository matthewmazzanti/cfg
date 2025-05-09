#!/usr/bin/env bash
set -xeuo pipefail

SYSTEM="home-assistant2"

if ! command -v git; then
    nix-env -iA nixpkgs.git
fi

mkdir ~/src/nix
git clone https://github.com/matthewmazzanti/cfg.git ~/src/nix/cfg
nixos-install --root /mnt --flake "~/src/nix/cfg#$SYSTEM"
