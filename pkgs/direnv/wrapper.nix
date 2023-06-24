{ stdenvNoCC, lib, symlinkJoin, makeWrapper }:
let
  mkConfigDir = { direnvrc ? "" }@args:
    stdenvNoCC.mkDerivation (args // {
      name = "direnv-config";
      passAsFile = builtins.attrNames args;
      # $passAsFile in builder seems to ignore empty strings/files
      buildCommand = ''
        mkdir -p "$out/direnv"
        for var in $passAsFile; do
            varPath="''${var}Path"
            varPath="''${!varPath}"

            outPath="$out/direnv/$var"
            cp "$varPath" "$outPath"
        done
      '';
    });

  wrapper =
    { direnv
    , direnvrc ? ""
    }:
    let
      configDir = mkConfigDir {
        inherit direnvrc;
      };
    in
    symlinkJoin {
      name = "direnv";
      paths = [ direnv ];
      buildInputs = [ makeWrapper ];
      postBuild = ''
        name="direnv"
        exe="$out/bin/$name"
        unwrapped="$out/bin/$name-unwrapped"
        mv "$exe" "$unwrapped"
        makeWrapper \
          "$(readlink -f "$unwrapped")" "$exe" \
          --set XDG_CONFIG_HOME "${configDir}"
      '';
    };
in
lib.makeOverridable wrapper
