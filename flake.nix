{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # NixOS modules
    lanzaboote.url = "github:nix-community/lanzaboote/v0.4.3";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    impermanence.url = "github:nix-community/impermanence";

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    # Neovim plugins
    vim-easyclip.url = "github:svermeulen/vim-easyclip/master";
    vim-easyclip.flake = false;

    # Home assistant plugins
    slider-entity-row.url = "github:thomasloven/lovelace-slider-entity-row";
    slider-entity-row.flake = false;
  };

  outputs = { self, nixpkgs, ... }@inputs: let
    lib = import ./lib nixpkgs;
    sys = import ./sys { inherit self inputs; };
  in {
    inherit lib;

    packages = lib.eachSystem ({
      pkgs,
      system,
    }:
      (import ./pkgs {
        inherit pkgs system inputs;
      }) // {
        home-manager = inputs.home-manager.packages.${system}.default;
        ghostty = inputs.ghostty.packages.${system}.default;
      }
    );

    devShell = lib.eachSystemShell ({pkgs, ...}: {
      packages = with pkgs; [
        nix-tree
        go
        uv
        alejandra
        neovim-unwrapped.lua
        gcc
        cargo
      ];
    });

    nixosModules = {
      quadlet = inputs.quadlet-nix.nixosModules.quadlet;
      impermanence = import ./modules/nixos/impermanence.nix;
      lanzaboote = import ./modules/nixos/lanzaboote.nix;
      base = import ./modules/nixos/base.nix;
    };

    nixosConfigurations = sys.nixos;
    darwinConfigurations = sys.darwin;
    homeConfigurations = sys.home;
  };
}
