{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    nvim.url = "git+file:.?dir=pkgs/nvim";
    nvim.inputs.flake-utils.follows = "flake-utils";
    nvim.inputs.nixpkgs.follows = "nixpkgs";

    zsh.url = "git+file:.?dir=pkgs/zsh";
    zsh.inputs.flake-utils.follows = "flake-utils";
    zsh.inputs.nixpkgs.follows = "nixpkgs";

    short-pwd.url = "git+file:.?dir=pkgs/short-pwd";
    short-pwd.inputs.flake-utils.follows = "flake-utils";
    short-pwd.inputs.nixpkgs.follows = "nixpkgs";

    direnv.url = "git+file:.?dir=pkgs/direnv";
    direnv.inputs.flake-utils.follows = "flake-utils";
    direnv.inputs.nixpkgs.follows = "nixpkgs";

    less.url = "git+file:.?dir=pkgs/less";
    less.inputs.flake-utils.follows = "flake-utils";
    less.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self
    , nixpkgs
    , darwin
    , flake-utils
    , deploy-rs
    , nvim
    , zsh
    , direnv
    , less
    , short-pwd
    , ...
    }: (
      (flake-utils.lib.eachDefaultSystem (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            nix-tree
            poetry
            go
            deploy-rs.packages.${system}.default
          ];
        };
      })) // {
        darwinConfigurations.beta = darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs.custom = {
            nvim = nvim.packages.aarch64-darwin.dev;
            zsh = zsh.packages.aarch64-darwin.dev;
            short-pwd = short-pwd.packages.aarch64-darwin.default;
            direnv = direnv.packages.aarch64-darwin.dev;
            less = less.packages.aarch64-darwin.dev;
          };
          modules = [
            ./configuration.nix
          ];
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

        # checks = builtins.mapAttrs (system: deployLib:
        #   deployLib.deployChecks self.deploy
        # ) deploy-rs.lib;
      }
    );
}
