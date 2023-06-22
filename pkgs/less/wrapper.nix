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
        mv "$out/bin/less" "$out/bin/less-unwrapped"
        makeWrapper \
          "$out/bin/less-unwrapped" "$out/bin/less" \
          --add-flags '--lesskey-src=${lesskeyDrv}' \
          ${lib.escapeShellArgs wrapperArgs}
      '';
    };
in
lib.makeOverridable wrapper
