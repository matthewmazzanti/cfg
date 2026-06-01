update:
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
