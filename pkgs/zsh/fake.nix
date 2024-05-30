{
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { nixpkgs, flake-utils, ... }: with (import ../../lib nixpkgs); {
    packages = eachSystem ({ pkgs, ... }: {
      dev = pkgs.callPackage ./dev.nix { };
    });
  };
}
