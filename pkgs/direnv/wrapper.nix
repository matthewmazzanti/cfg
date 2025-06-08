{
  stdenvNoCC,
  symlinkJoin,
  makeWrapper,
  direnv,
  direnvrc ? "",
}: let
  configDir = stdenvNoCC.mkDerivation {
    name = "direnv-config";
    inherit direnvrc;
    passAsFile = ["direnvrc"];
    buildCommand = ''
      mkdir -p "$out"
      cp "$direnvrcPath" "$out/direnvrc"
    '';
  };
in
  symlinkJoin {
    name = "direnv";
    paths = [direnv];
    buildInputs = [makeWrapper];
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
  }
