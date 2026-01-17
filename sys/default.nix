{ self, inputs }:
let
  lib = inputs.nixpkgs.lib;

  # ---- Systems ----
  linux  = "x86_64-linux";
  darwin = "aarch64-darwin";
  systems = [ linux darwin ];

  # ---- Pkgs via legacyPackages + overlay (no extra import) ----
  systemPkgs = lib.genAttrs systems (system:
    import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      config.segger-jlink.acceptLicense = true;
    }
  );

  # ---- Flake args passed under specialArgs.flake ----
  flakeArgs = lib.genAttrs systems (system: {
    inherit inputs;
    packages = self.packages.${system};
    lib      = self.lib;
    modules  = self.nixosModules;
  });

  # ---- Constructors ----
  nixosSystem  = inputs.nixpkgs.lib.nixosSystem;
  darwinSystem = inputs.darwin.lib.darwinSystem;
  hmConfig     = inputs.home-manager.lib.homeManagerConfiguration;
in {
  # ---------------- NixOS ----------------
  nixos.framework = nixosSystem {
    pkgs = systemPkgs.${linux};
    specialArgs.flake = flakeArgs.${linux};
    modules = [ ./framework ];
  };

  home."mmazzanti@framework" = hmConfig {
    pkgs = systemPkgs.${linux};
    extraSpecialArgs.flake = flakeArgs.${linux};
    modules = [ ./framework/home.nix ];
  };

  nixos.desktop = nixosSystem {
    pkgs = systemPkgs.${linux};
    specialArgs.flake = flakeArgs.${linux};
    modules = [ ./desktop ];
  };

  home."mmazzanti@desktop" = hmConfig {
    pkgs = systemPkgs.${linux};
    extraSpecialArgs.flake = flakeArgs.${linux};
    modules = [ ./desktop/home.nix ];
  };

  nixos.server = nixosSystem {
    pkgs = systemPkgs.${linux};
    specialArgs.flake = flakeArgs.${linux};
    modules = [ ./server ];
  };

  nixos.ha = nixosSystem {
    pkgs = systemPkgs.${linux};
    specialArgs.flake = flakeArgs.${linux};
    modules = [ ./ha ];
  };

  nixos.print = nixosSystem {
    pkgs = systemPkgs.${linux};
    specialArgs.flake = flakeArgs.${linux};
    modules = [ ./print ];
  };

  nixos.live = nixosSystem {
    pkgs = systemPkgs.${linux};
    specialArgs.flake = flakeArgs.${linux};
    modules = [ ./live ];
  };

  # ---------------- Darwin ---------------
  darwin.beta = darwinSystem {
    pkgs = systemPkgs.${darwin};
    specialArgs.flake = flakeArgs.${darwin};
    modules = [ ./beta ];
  };

  darwin.delta = darwinSystem {
    pkgs = systemPkgs.${darwin};
    specialArgs.flake = flakeArgs.${darwin};
    modules = [ ./delta ];
  };
}
