{ callPackage
, less
}:
let
  wrapper = callPackage ./wrapper.nix { };
  lesskey = builtins.readFile ./lesskey;
  wrapperArgs = [
    "--add-flags"
    "--chop-long-lines"
    "--add-flags"
    "--RAW-CONTROL-CHARS"
    "--add-flags"
    "--quit-if-one-screen"
    "--add-flags"
    "--mouse"
    "--add-flags"
    "--wheel-lines=5"
    "--add-flags"
    "--ignore-case"
    "--add-flags"
    "--prompt=%lb/%L"
  ];
in
wrapper {
  inherit less lesskey wrapperArgs;
}
