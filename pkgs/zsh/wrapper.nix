{ lib, stdenvNoCC, makeWrapper, symlinkJoin }:
let
  mkZdotdir = { zshenv, zprofile, zshrc, zlogin, zlogout }@args:
    stdenvNoCC.mkDerivation (args // {
      name = "zdotdir";
      passAsFile = builtins.attrNames args;
      # $passAsFile in builder seems to ignore empty strings/files
      buildCommand = ''
        mkdir -p "$out"
        for var in $passAsFile; do
            varPath="''${var}Path"
            varPath="''${!varPath}"

            outPath="$out/.$var"
            cp "$varPath" "$outPath"
        done
      '';
    });

  wrapper =
    { zsh
    , zshenv ? ""
    , zprofile ? ""
    , zshrc ? ""
    , zlogin ? ""
    , zlogout ? ""
    }:
    let
      zdotdir = mkZdotdir {
        inherit zshenv zprofile zshrc zlogin zlogout;
      };
    in
    symlinkJoin {
      name = "zsh";
      paths = [ zsh ];
      buildInputs = [ makeWrapper ];
      postBuild = ''
        name="zsh"
        exe="$out/bin/$name"
        unwrapped="$out/bin/$name-unwrapped"
        mv "$exe" "$unwrapped"
        makeWrapper \
          "$(readlink -f "$unwrapped")" "$exe" \
          --set ZDOTDIR "${zdotdir}"
      '';
    };
in
lib.makeOverridable wrapper
