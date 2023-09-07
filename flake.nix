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
      nvim = (import ./pkgs/nvim/fake.nix).outputs inputs;
      zsh = (import ./pkgs/zsh/fake.nix).outputs inputs;
      short-pwd = (import ./pkgs/short-pwd/fake.nix).outputs inputs;
      direnv = (import ./pkgs/direnv/fake.nix).outputs inputs;
      less = (import ./pkgs/less/fake.nix).outputs inputs;

      outputs = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          packages = {
            nvim = nvim.packages.${system};
            zsh = zsh.packages.${system};
            short-pwd = short-pwd.packages.${system};
            direnv = direnv.packages.${system};
            less = less.packages.${system};
          };

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

      configuration = {
        darwinConfigurations.beta =
          let
            system = "aarch64-darwin";
          in
          darwin.lib.darwinSystem {
            inherit system;
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
