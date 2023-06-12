{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";

    nvim.url = "git+file:.?dir=pkgs/nvim";
    nvim.inputs.flake-utils.follows = "flake-utils";
    nvim.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, flake-utils, darwin, nixpkgs, nvim, ... }: (
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
        modules = [
          ./configuration.nix
          {
            environment.systemPackages = [
              nvim.packages.aarch64-darwin.nvim
            ];
          }
        ];
      };
    }
  );
}
