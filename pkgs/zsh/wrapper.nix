{ stdenv, lib, symlinkJoin, makeWrapper }:
let
  mkZdotdir = { zshenv, zprofile, zshrc, zlogin, zlogout }@args:
    stdenv.mkDerivation (args // {
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
    , wrapperArgs ? [ ]
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
        mv "$out/bin/zsh" "$out/bin/zsh-unwrapped"
        makeWrapper \
          "$out/bin/zsh-unwrapped" "$out/bin/zsh" \
          --set ZDOTDIR "${zdotdir}"
      '';
    };
in
lib.makeOverridable wrapper
