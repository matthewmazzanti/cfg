update: check-pyatv
    nix flake update
    lock-images --json lib/images.json --write

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

upgrade-remote system:
    git push {{system}}:src/nix/cfg
    ssh -t {{system}} 'sudo nixos-rebuild switch --flake ~/src/nix/cfg -L'
    ssh -t {{system}} 'home-manager switch --flake ~/src/nix/cfg -L || true'

clean:
    nix-collect-garbage --delete-old
    sudo nix-collect-garbage --delete-old
    sudo /run/current-system/bin/switch-to-configuration boot

# Fails (exit 1) when the pyatv override (PR postlund/pyatv#2855) should be revisited:
# a v0.18.0+ release exists, or there are new commits on the default branch since
# the pinned commit. Exits 0 when nothing has changed upstream.
check-pyatv:
    #!/usr/bin/env bash
    set -euo pipefail
    repo="postlund/pyatv"
    pinned=$(grep -oP 'pyatvRef = "\K[0-9a-f]+' sys/ha/home-automation.nix)
    echo "Pinned pyatv commit: $pinned"

    echo
    echo "== Releases (looking for v0.18.0 or newer) =="
    tags=$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=20" | jq -r '.[].tag_name')
    echo "$tags" | head -5
    while read -r tag; do
        [ -z "$tag" ] && continue
        v=${tag#v}
        if [ "$(printf '%s\n%s\n' "$v" "0.18.0" | sort -V | tail -1)" = "$v" ]; then
            echo
            echo "Found pyatv $tag (>= v0.18.0)."
            echo "Please remove the pyatv override"
            exit 1
        fi
    done <<< "$tags"

    echo
    branch=$(curl -fsSL "https://api.github.com/repos/$repo" | jq -r '.default_branch')
    echo "== $branch HEAD =="
    head=$(curl -fsSL "https://api.github.com/repos/$repo/commits/$branch" | jq -r '.sha')
    echo "$branch is at: $head"
    if [ "$head" = "$pinned" ]; then
        echo "No new commits on $branch since the pinned commit."
    else
        echo "New commits on $branch since the pinned commit:"
        curl -fsSL "https://api.github.com/repos/$repo/compare/$pinned...$branch" \
            | jq -r '.commits[] | "  \(.sha[0:9]) \(.commit.message | split("\n")[0])"'
        exit 1
    fi

# Push a repo dashboard YAML to HA live via the websocket API (no restart). Needs
# HASS_TOKEN or ~/.config/ha/token (URL defaults to https://hass.iot). The seed
# baseline still wins on the next hass restart / rebuild, so commit to persist.
push-ui file="sys/ha/ui-lovelace.yaml":
    uv run scripts/lovelace.py push {{file}}

# Pull HA's current dashboard config back into a repo YAML (captures live/UI edits
# before a restart resets them to the committed baseline).
pull-ui file="sys/ha/ui-lovelace.yaml":
    uv run scripts/lovelace.py pull {{file}}
