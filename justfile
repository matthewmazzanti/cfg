update:
    nix flake lock
    lock-images --json lib/images.json --write

upgrade: upgrade-system upgrade-home

upgrade-system:
    sudo nixos-rebuild switch --flake ~/src/nix/cfg -L

upgrade-home:
    home-manager switch --flake ~/src/nix/cfg
