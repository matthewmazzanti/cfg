{
  self,
  inputs,
}: let
  system = "x86_64-linux";

  nixosSystem = inputs.nixpkgs.lib.nixosSystem;

  flake = {
    inherit inputs;
    packages = self.packages.${system};
    lib = self.lib;
    modules = self.nixosModules;
  };
in {
  lambda = nixosSystem {
    inherit system;
    specialArgs.custom = self.packages.${system};
    modules = [
      ({pkgs, ...}: {
        imports = [inputs.home-manager.nixosModules.home-manager];

        nix.extraOptions = "experimental-features = nix-command flakes";

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs.custom = self.packages.${pkgs.system};
        };
      })
      ./lambda
    ];
  };

  omega = nixosSystem {
    inherit system;
    specialArgs.custom = self.packages.${system};
    modules = [
      ({pkgs, ...}: {
        imports = [inputs.home-manager-old.nixosModules.home-manager];

        nix.extraOptions = "experimental-features = nix-command flakes";

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs.custom = self.packages.${pkgs.system};
        };
      })
      ./omega
    ];
  };

  framework = nixosSystem {
    inherit system;
    specialArgs.flake = flake;
    modules = [
      ./framework
    ];
  };

  server = nixosSystem {
    inherit system;
    specialArgs.flake = flake;
    modules = [ ./server ];
  };

  ha = nixosSystem {
    inherit system;
    specialArgs.flake = flake;
    modules = [ ./ha ];
  };

  print = nixosSystem {
    inherit system;
    specialArgs.flake = flake;
    modules = [ ./print ];
  };

  live = nixosSystem {
    inherit system;
    specialArgs.flake = flake;
    modules = [ ./live ];
  };
}
