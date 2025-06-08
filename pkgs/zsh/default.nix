{ pkgs, ...}: {
  "zsh/dev" = pkgs.callPackage ./dev.nix {};
}
