{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    with flake-utils.lib;
    eachSystem defaultSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.buildGoPackage {
          pname = "short-pwd";
          version = "0.0.3";
          goPackagePath = "github.com/matthewmazzanti/cfg/short-pwd";
          src = ./.;
          meta = {
            description = "Print a path shortened to a number of columns";
          };
        };
      }
    );
}
