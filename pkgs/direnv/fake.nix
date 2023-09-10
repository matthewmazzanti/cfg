{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    direnv-patched.url = "github:matthewmazzanti/direnv/master";
    direnv-patched.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, flake-utils, direnv-patched, ... }:
    with flake-utils.lib;
    eachSystem defaultSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        direnv = direnv-patched.packages.${system}.default;
      in
      {
        packages.dev = pkgs.callPackage ./dev.nix { inherit direnv; };
      }
    );
}
