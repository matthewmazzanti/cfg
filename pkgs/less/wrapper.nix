{ lib, symlinkJoin, makeWrapper, writeText }:
let
  wrapper =
    { less
    , lesskey
    , wrapperArgs ? [ ]
    }:
    let
      lesskeyDrv = writeText "lesskey" lesskey;
    in
    symlinkJoin {
      name = "less";
      paths = [ less ];
      buildInputs = [ makeWrapper ];
      postBuild = ''
        name="less"
        exe="$out/bin/$name"
        unwrapped="$out/bin/$name-unwrapped"
        mv "$exe" "$unwrapped"
        makeWrapper \
          "$(readlink -f "$unwrapped")" "$exe" \
          --add-flags '--lesskey-src=${lesskeyDrv}' \
          ${lib.escapeShellArgs wrapperArgs}
      '';
    };
in
lib.makeOverridable wrapper
