{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }: let
    inherit (import ../../lib nixpkgs) eachSystem;
  in {
    packages = eachSystem ({ pkgs, ... }: {
      dev = pkgs.callPackage ./dev.nix { };
    });
  };
}
