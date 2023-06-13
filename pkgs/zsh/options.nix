{ pkgs, lib, ... }:
with lib;
let
  direnv = { pkgs, lib, ... }:
    with lib;
    {
      options.plugins.direnv = {
        enable = mkEnableOption "direnv";

        package = mkOption {
          type = types.package;
          default = pkgs.direnv;
        };

        finalPackage = mkOption {
          type = types.package;
          readOnly = true;
        };
      };

      config.plugins.direnv = mkIf { };
    };

  fzf = {
    enable = mkEnableOption "fzf";

    package = mkOption {
      type = types.package;
      default = pkgs.fzf;
    };

    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
    };
  };

  fast-syntax-highlighting = {
    enable = mkEnableOption "fast-syntax-highlighting";

    theme = mkOption {
      type = types.nullOr types.str;
      default = "";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.zsh-fast-syntax-highlighting;
    };

    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
    };
  };

  autosuggestions = {
    enable = mkEnableOption "autosuggestions";

    package = mkOption {
      type = types.package;
      default = pkgs.zsh-autosuggestions;
    };

    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
    };
  };

in
{
  options = {
    compinit = mkOption {
      type = types.bool;
      default = false;
      description = ''
        run compinit
      '';
    };

    bashcompinit = mkOption {
      type = types.bool;
      default = false;
      description = ''
        run bashcompinit
      '';
    };

    path = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = ''
        derivations to add to path
      '';
    };

    zshrc = mkOption {
      type = types.str;
      default = "";
    };

    plugins = { };
  };
}
