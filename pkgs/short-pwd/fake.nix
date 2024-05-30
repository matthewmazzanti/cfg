{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }: let
    inherit (import ../../lib nixpkgs) eachSystem;
  in {
    packages = eachSystem ({ pkgs, ... }: {
      default = pkgs.buildGoPackage {
        pname = "short-pwd";
        version = "0.0.3";
        goPackagePath = "github.com/matthewmazzanti/cfg/short-pwd";
        src = ./.;
        meta = {
          description = "Print a path shortened to a number of columns";
        };
      };
    });
  };
}
