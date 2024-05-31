{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vim-easyclip-src = {
      url = "github:svermeulen/vim-easyclip/master";
      flake = false;
    };

    gruvbox-community-src = {
      url = "github:gruvbox-community/gruvbox/master";
      flake = false;
    };

    vim-pgsql-src = {
      url = "github:lifepillar/pgsql.vim/master";
      flake = false;
    };

    picom-next-src = {
      url = "github:yshui/picom/next";
      flake = false;
    };

    neovim = {
      url = "github:matthewmazzanti/nvim-flake/dev";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { home-manager, nixpkgs, ... }@inputs: let
    base = { pkgs, ... }: {
      imports = [ home-manager.nixosModules.home-manager ];

      nixpkgs.overlays = [(self: super: let
        buildPlugin = super.vimUtils.buildVimPluginFrom2Nix;
        versionOf = src: builtins.toString src.lastModified;
      in {
        vimPlugins = super.vimPlugins // {
          gruvbox-community = buildPlugin {
            pname = "gruvbox-community";
            version = versionOf inputs.gruvbox-community-src;
            src = inputs.gruvbox-community-src;
          };

          vim-easyclip = buildPlugin {
            pname = "vim-easyclip";
            version = versionOf inputs.vim-easyclip-src;
            src = inputs.vim-easyclip-src;
            dependencies = with super.vimPlugins; [ vim-repeat ];
          };

          vim-pgsql = buildPlugin {
            pname = "vim-pgsql";
            version = versionOf inputs.vim-pgsql-src;
            src = inputs.vim-pgsql-src;
          };

          orgmode-nvim = buildPlugin {
            pname = "orgmode-nvim";
            version = versionOf inputs.orgmode-nvim-src;
            src = inputs.orgmode-nvim-src;
          };
        };

        /*
        picom-next = super.picom.overrideAttrs (attrs: {
          src = inputs.picom-next-src;
          version = versionOf inputs.picom-next-src;
        });
        */
      })];

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
