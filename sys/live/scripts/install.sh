#!/usr/bin/env bash
set -xeuo pipefail

# Install nixos
nixos-install \
    --root /mnt \
    --no-channel-copy \
    --no-root-password \
    --flake "$SUDO_HOME/src/nix/cfg#live"
