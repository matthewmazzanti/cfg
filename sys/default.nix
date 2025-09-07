{ self, inputs }:
let
  lib = inputs.nixpkgs.lib;

  # ---- Systems ----
  linux  = "x86_64-linux";
  darwin = "aarch64-darwin";
  systems = [ linux darwin ];

  # ---- Overlay that flips allowUnfree ----
  unfreeOverlay = _: prev: {
    config = (prev.config or {}) // {
      allowUnfree = true;
    };
  };

  # ---- Pkgs via legacyPackages + overlay (no extra import) ----
  systemPkgs = lib.genAttrs systems (system:
    import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
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

  # ---- Reusable HM activation (Linux via systemd) ----
  hmServiceLinux = { username, config }: { pkgs, ... }: let
    activationPackage = config.activationPackage;
  in {
    systemd.services."hm-${username}-activate" = {
      description = "Activate Home Manager profile for ${username}";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "nss-user-lookup.target" "local-fs.target" ];
      serviceConfig = {
        Type        = "oneshot";
        User        = username;
        Environment = "HOME=%h";
        ExecStart   = "${activationPackage}/activate --driver-version 1";
        RemainAfterExit = true;
      };
      restartTriggers = [ activationPackage ];
    };
  };

  # ---- Reusable HM activation (Darwin via launchd) ----
  hmDarwinAgent = { username, config }: { ... }: {
    launchd.user.agents."hm-${username}-activate" = let
      activationPackage = config.activationPackage;
    in {
      enable = true;
      config = {
        ProgramArguments = [
          "${activationPackage}/activate"
          "--driver-version" "1"
        ];
        # Run when the agent is loaded (e.g., at login or when reloaded)
        RunAtLoad = true;
        # Do not restart automatically; one-shot activation re-applies on agent
        # reload
        KeepAlive = false;
      };
    };
  };
in rec {
  # ---------------- NixOS ----------------
  nixos.framework = nixosSystem {
    pkgs = systemPkgs.${linux};
    specialArgs.flake = flakeArgs.${linux};
    modules = [
      ./framework
      # (hmServiceLinux {
      #   username = "mmazzanti";
      #   config   = home."mmazzanti@framework";
      # })
    ];
  };

  home."mmazzanti@framework" = hmConfig {
    pkgs = systemPkgs.${linux};
    extraSpecialArgs.flake = flakeArgs.${linux};
    modules = [ ./framework/home.nix ];
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
