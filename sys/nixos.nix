{
  self,
  inputs,
}: let
  inherit (inputs.nixpkgs.lib) nixosSystem;
  system = "x86_64-linux";
  flake = {
    inherit inputs;
    packages = self.pacakges.${system};
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

  home-assistant = nixosSystem {
    inherit system;
    specialArgs.haDeps = {
      slider-entity-row = inputs.slider-entity-row;
      pyscript = inputs.pyscript;
    };
    modules = [./home-assistant];
  };

  hass = nixosSystem {
    inherit system;
    specialArgs.flake = flake;
    modules = [ ./hass ];
  };

  live = nixosSystem {
    inherit system;
    specialArgs.flake = flake;
    modules = [ ./live ];
  };
}
