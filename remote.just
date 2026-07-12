# Fetch a host's repo, merge its dev branch, and push back.
sync system:
    git fetch {{system}}
    git merge {{system}}/dev
    git push {{system}}

# GC old generations and prune boot entries on a host.
clean system:
    ssh -t {{system}} 'nix-collect-garbage --delete-old'
    ssh -t {{system}} 'sudo nix-collect-garbage --delete-old'
    ssh -t {{system}} 'sudo /run/current-system/bin/switch-to-configuration boot'

# The remote re-evals its own checkout but finds the copied store paths already
# valid, so it activates instead of recompiling. `attr` defaults to the host with
# its domain stripped (desktop.lan -> desktop, ha.iot -> ha).
#
# Build locally, copy the closure(s) to the host, push the repo, then rebuild there.
deploy system attr=file_stem(system) user=env_var('USER'):
    #!/usr/bin/env bash
    set -euo pipefail
    # True iff the flake defines output attr `$1.$2` (checks names only, cheap).
    has() { nix eval ".#$1" --apply "builtins.hasAttr \"$2\"" 2>/dev/null | grep -qx true; }

    has nixosConfigurations "{{attr}}" \
        || { echo "error: no nixosConfigurations.{{attr}} in this flake" >&2; exit 1; }

    paths=$(nix build --no-link --print-out-paths \
        ".#nixosConfigurations.{{attr}}.config.system.build.toplevel")

    # Standalone home-manager only exists for some hosts; build+activate it only
    # when the flake actually defines it, so a real HM failure still aborts.
    hm=""
    if has homeConfigurations '{{user}}@{{attr}}'; then
        hm=$(nix build --no-link --print-out-paths \
            ".#homeConfigurations.\"{{user}}@{{attr}}\".activationPackage")
    fi

    nix copy --to "ssh://{{system}}" $paths $hm
    git push {{system}}
    ssh -t {{system}} 'sudo nixos-rebuild switch --flake ~/src/nix/cfg -L'
    if [ -n "$hm" ]; then
        ssh -t {{system}} 'home-manager switch --flake ~/src/nix/cfg -L'
    fi

# Push local repo and rebuild system + home on a host (remote does the build).
upgrade system:
    git push {{system}}
    ssh -t {{system}} 'sudo nixos-rebuild switch --flake ~/src/nix/cfg -L'
    ssh -t {{system}} 'home-manager switch --flake ~/src/nix/cfg -L' || true
