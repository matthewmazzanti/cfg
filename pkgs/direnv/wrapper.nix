{ stdenvNoCC, lib, symlinkJoin, makeWrapper }:
let
  mkConfigDir = { direnvrc ? "" }@args:
    stdenvNoCC.mkDerivation (args // {
      name = "direnv-config";
      passAsFile = builtins.attrNames args;
      # $passAsFile in builder seems to ignore empty strings/files
      buildCommand = ''
        mkdir -p "$out"
        for var in $passAsFile; do
            varPath="''${var}Path"
            varPath="''${!varPath}"

            outPath="$out/$var"
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
        wrapped="$out/bin/$name"
        unwrapped="$out/bin/$name-unwrapped"
        mv "$wrapped" "$unwrapped"
        makeWrapper \
          "$(readlink -f "$unwrapped")" "$wrapped" \
          --set DIRENV_SELF_PATH "$wrapped" \
          --set DIRENV_CONFIG '${configDir}'
      '';
    };
in
lib.makeOverridable wrapper
