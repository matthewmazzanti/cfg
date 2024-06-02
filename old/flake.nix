{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11";

    home-manager.url = "github:nix-community/home-manager/release-23.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { home-manager, nixpkgs, ... }@inputs: let
    base = { pkgs, ... }: {
      imports = [ home-manager.nixosModules.home-manager ];

      nix.extraOptions = "experimental-features = nix-command flakes";

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          neovim-flake = inputs.neovim.packages.x86_64-linux;
        };
      };
    };
  in {
    nixosConfigurations = {
      lambda = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ base ./systems/lambda.nix ];
      };

      omega = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ base ./systems/omega.nix ];
      };

      pi = inputs.nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ base ./modules ./systems/pi ];
      };
    };
  };
}
