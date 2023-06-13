{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";

    nvim.url = "git+file:.?dir=pkgs/nvim";
    nvim.inputs.flake-utils.follows = "flake-utils";
    nvim.inputs.nixpkgs.follows = "nixpkgs";

    zsh.url = "git+file:.?dir=pkgs/zsh";
    zsh.inputs.flake-utils.follows = "flake-utils";
    zsh.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, flake-utils, darwin, nixpkgs, nvim, zsh, ... }: (
    (flake-utils.lib.eachSystem flake-utils.lib.defaultSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixpkgs-fmt
          nix-tree
        ];
      };
    })) // {
      darwinConfigurations.beta = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs.custom = {
          nvim = nvim.packages.aarch64-darwin.dev;
          zsh = zsh.packages.aarch64-darwin.dev;
        };
        modules = [
          ./configuration.nix
        ];
      };
    }
  );
}
