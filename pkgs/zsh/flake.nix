{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }@inputs:
    with flake-utils.lib;
    eachSystem defaultSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.dev = pkgs.callPackage ./dev.nix { };
      }
    );
}
