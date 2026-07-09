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

# Push local repo and rebuild system + home on a host.
upgrade system:
    git push {{system}}:src/nix/cfg
    ssh -t {{system}} 'sudo nixos-rebuild switch --flake ~/src/nix/cfg -L'
    ssh -t {{system}} 'home-manager switch --flake ~/src/nix/cfg -L' || true
