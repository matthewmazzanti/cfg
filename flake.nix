{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Neovim plugins
    vim-easyclip.url = "github:svermeulen/vim-easyclip/master";
    vim-easyclip.flake = false;

    direnv-patched.url = "github:matthewmazzanti/direnv/master";
    direnv-patched.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, darwin, ... }@inputs:
    let
      inherit (import ./lib nixpkgs) eachSystem eachSystemFlattenFlakes;
    in {
      packages = eachSystemFlattenFlakes {
        # Workaround for subflake UX
        # Ideally I'd be able to reference a flake in the pkgs/ dir with a URL
        # in the inputs - something like path:/pkgs/nvim or
        # git+file:.?path=pkgs/nvim
        #
        # Neither of those work nicely though - updating is a pain, and things
        # will randomly break with both approaces. Instead, use a "fake.nix" -
        # a nix file following the flake spec, but loaded outside of the
        # typical flake workflow. This allows a better UX and consistency, at
        # the expense of having to define all inputs for all flakes at the
        # toplevel here.
        nvim = (import ./pkgs/nvim/fake.nix).outputs inputs;
        zsh = (import ./pkgs/zsh/fake.nix).outputs inputs;
        short-pwd = (import ./pkgs/short-pwd/fake.nix).outputs inputs;
        direnv = (import ./pkgs/direnv/fake.nix).outputs inputs;
        less = (import ./pkgs/less/fake.nix).outputs inputs;
      };

      devShells = eachSystem ({ pkgs, ... }: {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            nix-tree
            poetry
            go
          ];
        };
      });

      configuration.darwinConfigurations = {
        beta = darwin.lib.darwinSystem rec {
          system = "aarch64-darwin";
          specialArgs.custom = self.packages.${system};
          modules = [ ./sys/beta/configuration.nix ];
        };

        delta = darwin.lib.darwinSystem rec {
          system = "aarch64-darwin";
          specialArgs.custom = self.packages.${system};
          modules = [ ./sys/delta/configuration.nix ];
        };
      };
    };
}
