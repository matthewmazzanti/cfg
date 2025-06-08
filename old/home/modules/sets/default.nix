{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./terminal.nix
    ./graphical.nix
  ];
}
