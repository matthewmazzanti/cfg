{
  pkgs,
  lib,
  paths,
  plugins,
  ftplugin,
  init,
}: let
  pathPkg = pkgs.buildEnv {
    name = "nvim-path";
    paths = paths;
  };

  ftpluginPkg = pkgs.stdenvNoCC.mkDerivation (ftplugin
    // {
      name = "ftplugin";
      passAsFile = builtins.attrNames ftplugin;
      buildCommand = ''
        mkdir -p "$out/ftplugin"
        for var in $passAsFile; do
            pathVar="''${var}Path"
            cat "''${!pathVar}" > "$out/ftplugin/$var.lua"
        done
      '';
    });

  initPkg = pkgs.writeText "init.lua" (
    lib.strings.concatMapStringsSep "\n" (f: ''dofile("${f}")'') init
  );
in
  pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
    wrapRc = false;
    wrapperArgs = [
      # Add path item to wrapper
      "--suffix"
      "PATH"
      ":"
      ''${pathPkg}/bin''
      # Add generated init
      "--add-flags"
      ''-u ${initPkg}''
    ];
    withPython3 = false;
    withNodeJs = false;
    withRuby = false;
    vimAlias = true;
    plugins = [ftpluginPkg] ++ plugins;
  }
