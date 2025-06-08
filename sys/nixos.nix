{
  self,
  inputs,
}: let
  system = "x86_64-linux";
in {
  lambda = inputs.nixpkgs.lib.nixosSystem rec {
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
      ./sys/lambda
    ];
  };

  omega = inputs.nixpkgs-old.lib.nixosSystem rec {
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
      ./sys/omega
    ];
  };

  home-assistant = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs.haDeps = {
      slider-entity-row = inputs.slider-entity-row;
      pyscript = inputs.pyscript;
    };
    modules = [./sys/home-assistant];
  };

  hass = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs.flake = {
      slider-entity-row = inputs.slider-entity-row;
      pyscript = inputs.pyscript;
    };
    modules = [
      inputs.impermanence.nixosModules.impermanence
      inputs.lanzaboote.nixosModules.lanzaboote
      ./sys/hass
    ];
  };

  live = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs.flake = {};
    modules = [./sys/live];
  };
}
