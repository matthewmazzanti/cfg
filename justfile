update:
    nix flake update
    lock-images --json lib/images.json --write
    bump-kernel --flake . --json lib/pins.json --lts-kernel --write

# Rebuild + activate a host (by flake attr). No target = this machine. Flags:
# --only sys|hm, --build-on-host. Deploy mode (build local, copy) is the default.
upgrade *args:
    hostctl upgrade {{args}}

# Alias for `upgrade`. Deploy mode -- build locally, copy the closure, no remote
# recompile -- is upgrade's default for a remote target.
deploy *args:
    hostctl deploy {{args}}

# GC old generations + prune boot entries. No target = this machine.
clean *args:
    hostctl clean {{args}}

# Fetch a host's repo, merge its dev branch, and push back.
sync *args:
    hostctl sync {{args}}

# Push a repo dashboard YAML to HA live via the websocket API (no restart). Needs
# HASS_TOKEN or ~/.config/ha/token (URL defaults to https://hass.iot). The seed
# baseline still wins on the next hass restart / rebuild, so commit to persist.
push-ui file="sys/ha/ui-lovelace.yaml":
    uv run scripts/lovelace.py push {{file}}

# Pull HA's current dashboard config back into a repo YAML (captures live/UI edits
# before a restart resets them to the committed baseline).
pull-ui file="sys/ha/ui-lovelace.yaml":
    uv run scripts/lovelace.py pull {{file}}
