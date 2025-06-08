{
  self,
  inputs,
}: {
  lambda = inputs.nixpkgs.lib.nixosSystem rec {
    system = "x86_64-linux";
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
    system = "x86_64-linux";
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
    system = "x86_64-linux";
    specialArgs.haDeps = {
      slider-entity-row = inputs.slider-entity-row;
      pyscript = inputs.pyscript;
    };
    modules = [./sys/home-assistant];
  };

  hass = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
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
    system = "x86_64-linux";
    specialArgs.flake = {};
    modules = [./sys/live];
  };
}
