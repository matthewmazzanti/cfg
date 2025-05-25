{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    lanzaboote.url = "github:nix-community/lanzaboote/v0.4.2";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    impermanence.url = "github:nix-community/impermanence";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";

    # Neovim plugins
    vim-easyclip.url = "github:svermeulen/vim-easyclip/master";
    vim-easyclip.flake = false;

    direnv-patched.url = "github:matthewmazzanti/direnv/master";
    direnv-patched.inputs.nixpkgs.follows = "nixpkgs";

    # Old system compat
    nixpkgs-old.url = "nixpkgs/nixos-24.05";

    home-manager-old.url = "github:nix-community/home-manager/release-24.05";
    home-manager-old.inputs.nixpkgs.follows = "nixpkgs-old";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Home assistant plugins
    slider-entity-row.url = "github:thomasloven/lovelace-slider-entity-row";
    slider-entity-row.flake = false;
    pyscript.url = "github:custom-components/pyscript";
    pyscript.flake = false;
  };

  outputs = {
    self,
    nixpkgs,
    darwin,
    home-manager,
    home-manager-old,
    nixos-hardware,
    ...
  } @ inputs: let
    lib = (import ./lib nixpkgs);

    base = { pkgs, ... }: {
      imports = [ home-manager.nixosModules.home-manager ];

      nix.extraOptions = "experimental-features = nix-command flakes";

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs.custom = self.packages.${pkgs.system};
      };
    };

    base-old = { pkgs, ... }: {
      imports = [ home-manager-old.nixosModules.home-manager ];

      nix.extraOptions = "experimental-features = nix-command flakes";

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs.custom = self.packages.${pkgs.system};
      };
    };
  in {
    packages = lib.eachSystemFlattenFlakes {
      # Workaround for subflake UX
      # Ideally I'd be able to reference a flake in the pkgs/ dir with a URL
      # in the inputs - something like path:/pkgs/nvim or
      # git+file:.?path=pkgs/nvim
      #
      # Neither of those work nicely though - updating is a pain, and things
      # will randomly break with both approaces. Instead, use a "fake.nix" -
      # a nix file following the flake spec, but loaded outside of the
      # typical flake workflow. This allows a better UX and consistency, at
      # the expense of having to define all inputs for all flakes at the
      # toplevel here.
      nvim = (import ./pkgs/nvim/fake.nix).outputs inputs;
      zsh = (import ./pkgs/zsh/fake.nix).outputs inputs;
      short-pwd = (import ./pkgs/short-pwd/fake.nix).outputs inputs;
      direnv = (import ./pkgs/direnv/fake.nix).outputs inputs;
      less = (import ./pkgs/less/fake.nix).outputs inputs;
    };

    devShell = lib.eachSystemShell ({pkgs, ...}: {
      packages = with pkgs; [
        nix-tree
        go
        uv
      ];
    });

    formatter = lib.eachSystem ({pkgs, ...}: pkgs.alejandra);

    darwinConfigurations = {
      beta = darwin.lib.darwinSystem rec {
        system = "aarch64-darwin";
        specialArgs.custom = self.packages.${system};
        modules = [./sys/beta];
      };

      delta = darwin.lib.darwinSystem rec {
        system = "aarch64-darwin";
        specialArgs.custom = self.packages.${system};
        modules = [./sys/delta];
      };
    };

    nixosConfigurations = {
      lambda = inputs.nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs.custom = self.packages.${system};
        modules = [ base ./sys/lambda ];
      };

      omega = inputs.nixpkgs-old.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs.custom = self.packages.${system};
        modules = [ base-old ./sys/omega ];
      };

      home-assistant = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs.haDeps = {
          slider-entity-row = inputs.slider-entity-row;
          pyscript = inputs.pyscript;
        };
        modules = [ ./sys/home-assistant ];
      };

      hass = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs.haDeps = {
          slider-entity-row = inputs.slider-entity-row;
          pyscript = inputs.pyscript;
        };
        modules = [
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.impermanence.nixosModules.impermanence
          ./sys/hass
        ];
      };
    };
  };
}
