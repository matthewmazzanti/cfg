{ pkgs, lib, ... }: let
  modules = [
    ({ config, ... }: {
      options = {
        plugins.enable = lib.options.mkEnableOption "plugins";
        lsp.enable = lib.options.mkEnableOption "lsp";
        treesitter.enable = lib.options.mkEnableOption "treesitter";

        languageServers = {
          type = lib.types.listOf lib.types.package;
          default = [];
        };
        paths = lib.options.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [];
        };
        grammars = lib.options.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [];
        };
        pluginPkgs = lib.options.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [];
        };
        init = lib.options.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
        };

        args = {
          languageServers = {
            type = lib.types.listOf lib.types.package;
            default = [];
          };
          paths = lib.options.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [];
          };
          grammars = lib.options.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [];
          };
          plugins = lib.options.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [];
          };
          init = lib.options.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
        };
      };
    })
    ({ config, grammars, ... }: {
      options.langs.c = {
        enable = lib.options.mkEnableOption "c";
        treesitter = lib.options.mkOption {
          default = lib.mkDefault config.treesitter;
        };
        langServer = lib.options.mkOption {
          default = lib.mkDefault config.langs;
        };
      };
      config.args = lib.mkIf config.langs.c.enable {
        languageServers = [ pkgs.ccls ];
        grammars = [ grammars.c grammars.cpp ];
      };
    })
    ({ config, grammars, ... }: {
      options.langs.go.enable = lib.options.mkEnableOption "go";
      config.args = lib.mkIf config.langs.go.enable {
        languageServers = [ pkgs.gopls ];
        grammars = [ grammars.go ];
      };
    })
    ({ config, grammars, ... }: {
      options.langs.nix.enable = lib.options.mkEnableOption "nix";
      config.args = lib.mkIf config.langs.nix.enable {
        languageServers = [ pkgs.nil ];
        grammars = [ grammars.nix ];
      };
    })
    ({
      plugins.enable = true;
      lsp.enable = true;
      treesitter.enable = true;
      langs.c.enable = true;
      langs.nix.enable = true;
    })
  ];

in (lib.evalModules {
  inherit modules;
  specialArgs.grammars = pkgs.vimPlugins.nvim-treesitter.builtGrammars;
}).config.args
