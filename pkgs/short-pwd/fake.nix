{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = {nixpkgs, ...}: let
    inherit (import ../../lib nixpkgs) eachSystem;
  in {
    packages = eachSystem ({pkgs, ...}: {
      default = pkgs.buildGoModule {
        pname = "short-pwd";
        version = "0.0.3";
        vendorHash = null;
        src = ./.;
        meta = {
          description = "Print a path shortened to a number of columns";
        };
      };
    });
  };
}
