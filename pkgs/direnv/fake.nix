{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    direnv-patched.url = "github:matthewmazzanti/direnv/master";
    direnv-patched.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    nixpkgs,
    direnv-patched,
    ...
  }: let
    inherit (import ../../lib nixpkgs) eachSystem;
  in {
    packages = eachSystem ({
      pkgs,
      system,
      ...
    }: {
      dev = pkgs.callPackage ./dev.nix {
        direnv = direnv-patched.packages.${system}.default;
      };
    });
  };
}
