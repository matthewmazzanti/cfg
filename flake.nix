{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    # Neovim plugins
    vim-easyclip.url = "github:svermeulen/vim-easyclip/master";
    vim-easyclip.flake = false;

    # Fork to fix htmldjango
    # TODO: Upstream these changes
    nvim-ts-autotag.url = "github:matthewmazzanti/nvim-ts-autotag/main";
    nvim-ts-autotag.flake = false;

    direnv-patched.url = "github:matthewmazzanti/direnv/master";
    direnv-patched.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self
    , nixpkgs
    , darwin
    , flake-utils
    , deploy-rs
    , ...
    }@inputs:
    let
      inherit (flake-utils.lib) eachDefaultSystem flattenTree;
      # Workaround for subflake UX
      # Ideally I'd be able to reference a flake in the pkgs/ dir with a URL in
      # the inputs - something like path:/pkgs/nvim or git+file:.?path=pkgs/nvim
      #
      # Neither of those work nicely though - updating is a pain, and things
      # will randomly break with both approaces. Instead, use a "fake.nix" - a
      # nix file following the flake spec, but loaded outside of the typical
      # flake workflow. This allows a better UX and consistency, at the expense
      # of having to define all inputs for all flakes at the toplevel here.
      nvim = (import ./pkgs/nvim/fake.nix).outputs inputs;
      zsh = (import ./pkgs/zsh/fake.nix).outputs inputs;
      short-pwd = (import ./pkgs/short-pwd/fake.nix).outputs inputs;
      direnv = (import ./pkgs/direnv/fake.nix).outputs inputs;
      less = (import ./pkgs/less/fake.nix).outputs inputs;

      # General outputs
      # Provided for all default systems
      outputs = eachDefaultSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # Packages doesn't allow nested outputs - use flatten tree to fix
          # this. Requires some massaging to set the `recurseForDerivations`
          # attribute on each sub-item
          packages = let
            # TODO: Custom implementation with an unflatten reversal?
            recurse = builtins.mapAttrs (_: value: 
              value // { recurseForDerivations = true; }
            );
          in flattenTree (recurse {
            nvim = nvim.packages.${system};
            zsh = zsh.packages.${system};
            short-pwd = short-pwd.packages.${system};
            direnv = direnv.packages.${system};
            less = less.packages.${system};
          });

          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixpkgs-fmt
              nix-tree
              poetry
              go
              deploy-rs.packages.${system}.default
            ];
          };
        });

      # System configurations
      # In separate attr set since they only build for a single arch
      configuration = {
        darwinConfigurations.beta = darwin.lib.darwinSystem rec {
          system = "aarch64-darwin";
          specialArgs.custom = self.packages.${system};
          modules = [ ./configuration.nix ];
        };

        nixosConfigurations.beta-build = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./sys/beta-build ];
        };

        deploy.nodes.beta-build = {
          hostname = "192.168.65.2";
          sshUser = "build";
          user = "root";
          remoteBuild = true;

          profiles.system.path = deploy-rs.lib.x86_64-linux.activate.nixos
            self.nixosConfigurations.beta-build;
        };
      };
    in
    outputs // configuration;
}
