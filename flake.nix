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
    impermanence.inputs.nixpkgs.follows = "nixpkgs";
    impermanence.inputs.home-manager.follows = "home-manager";

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    # Direnv plugins
    nix-direnv.url = "github:nix-community/nix-direnv/master";
    nix-direnv.inputs.nixpkgs.follows = "nixpkgs";

    # Neovim plugins
    vim-easyclip.url = "github:svermeulen/vim-easyclip/master";
    vim-easyclip.flake = false;

    # Home assistant plugins
    slider-entity-row.url = "github:thomasloven/lovelace-slider-entity-row";
    slider-entity-row.flake = false;

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, ... }@inputs: let
    lib = import ./lib nixpkgs;
    sys = import ./sys { inherit self inputs; };
  in {
    inherit lib;

    packages = lib.eachSystem ({ pkgs, system, }: let
      localPkgs = import ./pkgs {
        inherit pkgs system inputs;
      };

      pkgFor = input: input.packages.${system}.default;
    in localPkgs // {
      home-manager = pkgFor inputs.home-manager;
      ghostty = pkgFor inputs.ghostty;
      nix-direnv = pkgFor inputs.nix-direnv;
    });

    devShell = lib.eachSystemShell ({pkgs, ...}: {
      packages = with pkgs; [
        nix-tree
        alejandra
        neovim-unwrapped.lua
        uv
        just
      ];
    });

    nixosModules = {
      quadlet = inputs.quadlet-nix.nixosModules.quadlet;
      hardware = inputs.nixos-hardware.nixosModules;
      impermanence = import ./modules/nixos/impermanence.nix;
      lanzaboote = import ./modules/nixos/lanzaboote.nix;
      base = import ./modules/nixos/base.nix;
    };

    nixosConfigurations = sys.nixos;
    darwinConfigurations = sys.darwin;
    homeConfigurations = sys.home;
  };
}
