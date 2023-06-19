{ callPackage
, tmux
}:
let
  wrapper = callPackage ./wrapper.nix { };
  conf = builtins.readFile ./tmux.conf;
in
wrapper {
  inherit tmux conf;
}
