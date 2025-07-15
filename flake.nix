{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs";
    # Old system compat
    nixpkgs-old.url = "nixpkgs/nixos-24.05";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Build systems
    gomod2nix.url = "github:nix-community/gomod2nix";
    gomod2nix.inputs.nixpkgs.follows = "nixpkgs";

    # NixOS modules
    lanzaboote.url = "github:nix-community/lanzaboote/v0.4.2";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    impermanence.url = "github:nix-community/impermanence";

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Neovim plugins
    vim-easyclip.url = "github:svermeulen/vim-easyclip/master";
    vim-easyclip.flake = false;

    direnv-patched.url = "github:matthewmazzanti/direnv/master";
    direnv-patched.inputs.nixpkgs.follows = "nixpkgs";
    # Fixing a bug where gomod2nix was selecting go1.22 after deprecation
    direnv-patched.inputs.gomod2nix.follows = "gomod2nix";

    home-manager-old.url = "github:nix-community/home-manager/release-24.05";
    home-manager-old.inputs.nixpkgs.follows = "nixpkgs-old";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Home assistant plugins
    slider-entity-row.url = "github:thomasloven/lovelace-slider-entity-row";
    slider-entity-row.flake = false;
    pyscript.url = "github:custom-components/pyscript";
    pyscript.flake = false;
  };

  outputs = {
    self,
    nixpkgs,
    darwin,
    home-manager,
    home-manager-old,
    nixos-hardware,
    ...
  } @ inputs: let
    lib = import ./lib nixpkgs;
  in {
    inherit lib;

    packages = lib.eachSystem ({
      pkgs,
      system,
    }: (
      import ./pkgs {
        inherit pkgs system inputs;
      }
    ));

    devShell = lib.eachSystemShell ({pkgs, ...}: {
      packages = with pkgs; [
        nix-tree
        go
        uv
        alejandra
        neovim-unwrapped.lua
      ];
    });

    darwinConfigurations = import ./sys/darwin.nix {
      inherit self inputs;
    };

    nixosModules = {
      quadlet = inputs.quadlet-nix.nixosModules.quadlet;
      impermanence = import ./modules/nixos/impermanence.nix;
      lanzaboote = import ./modules/nixos/lanzaboote.nix;
      base = import ./modules/nixos/base.nix;
    };

    nixosConfigurations = import ./sys/nixos.nix {
      inherit self inputs;
    };
  };
}
