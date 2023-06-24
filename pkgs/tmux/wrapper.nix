{ lib, symlinkJoin, makeWrapper, writeText }:
let
  wrapper =
    { tmux
    , conf ? ""
    }:
    let
      confDrv = writeText "tmux.conf" conf;
    in
    symlinkJoin {
      name = "tmux";
      paths = [ tmux ];
      buildInputs = [ makeWrapper ];
      postBuild = ''
        name="tmux"
        exe="$out/bin/$name"
        unwrapped="$out/bin/$name-unwrapped"
        mv "$exe" "$unwrapped"
        makeWrapper \
          "$(readlink -f "$unwrapped")" "$exe" \
          --add-flags '-f ${confDrv}'
      '';
    };
in
lib.makeOverridable wrapper
