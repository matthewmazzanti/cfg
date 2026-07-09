update:
    nix flake update
    lock-images --json lib/images.json --write
    bump-kernel --flake . --json lib/pins.json --lts-kernel --write

upgrade: upgrade-system upgrade-home

upgrade-system:
    #!/usr/bin/env bash
    case "$(uname)" in
        Linux)
            sudo nixos-rebuild switch --flake ~/src/nix/cfg -L;;
        Darwin)
            sudo darwin-rebuild switch --flake ~/src/nix/cfg -L;;
    esac


upgrade-home:
    home-manager switch --flake ~/src/nix/cfg -L

# Per-host operations over ssh: `just remote sync|clean|upgrade <host>`.
mod remote

clean:
    nix-collect-garbage --delete-old
    sudo nix-collect-garbage --delete-old
    sudo /run/current-system/bin/switch-to-configuration boot

# Push a repo dashboard YAML to HA live via the websocket API (no restart). Needs
# HASS_TOKEN or ~/.config/ha/token (URL defaults to https://hass.iot). The seed
# baseline still wins on the next hass restart / rebuild, so commit to persist.
push-ui file="sys/ha/ui-lovelace.yaml":
    uv run scripts/lovelace.py push {{file}}

# Pull HA's current dashboard config back into a repo YAML (captures live/UI edits
# before a restart resets them to the committed baseline).
pull-ui file="sys/ha/ui-lovelace.yaml":
    uv run scripts/lovelace.py pull {{file}}
