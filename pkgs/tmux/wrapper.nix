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
        exe="$out/bin/tmux"
        unwrapped="$out/bin/tmux-unwrapped"
        mv "$exe" "$unwrapped"
        makeWrapper \
          "$(readlink -f "$unwrapped")" "$exe" \
          --add-flags '-f ${confDrv}'
      '';
    };
in
lib.makeOverridable wrapper
