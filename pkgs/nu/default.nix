{
  pkgs,
  system,
  inputs
}: let
  nuWrapper = pkgs.callPackage ./wrap.nix { };
  nu = nuWrapper {
    config = builtins.path {
      path = ./config;
    };
  };
in {
  inherit nuWrapper nu;
}
