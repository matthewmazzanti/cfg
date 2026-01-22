update:
    nix flake lock
    lock-images --json lib/images.json --write

upgrade:
    sudo nixos-rebuild switch --flake ~/src/nix/cfg -L
    home-manager switch --flake ~/src/nix/cfg -L

upgrade-remote system:
    git push {{system}}:src/nix/cfg
    ssh -t {{system}} 'sudo nixos-rebuild switch --flake ~/src/nix/cfg -L'
    ssh -t {{system}} 'home-manager switch --flake ~/src/nix/cfg -L'
