{
  pkgs,
  lib,
  packages,
  plugins,
  ftplugin,
  init,
}: let
  ftpluginPkg = pkgs.stdenvNoCC.mkDerivation (ftplugin // {
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
in
  pkgs.callPackage ./wrapper2.nix {
    inherit packages;
    plugins = [ftpluginPkg] ++ plugins;
    init = lib.strings.concatMapStringsSep "\n" (f: ''dofile("${f}")'') init;
  }
