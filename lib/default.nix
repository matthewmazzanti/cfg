nixpkgs: let
  inherit (nixpkgs.lib) genAttrs nameValuePair concatMapAttrs;
  inherit (builtins) attrNames listToAttrs;
in rec {
  # List of nixpkgs systems identifiers for flakes
  systems = ["aarch64-linux" "aarch64-darwin" "x86_64-linux"];

  # For each system, run `f` over the system name and nixpkgs, and collect the
  # results into an attribute set, with system as the key
  eachSystem = f:
    genAttrs systems (
      system:
        f {
          system = system;
          pkgs = nixpkgs.legacyPackages.${system};
        }
    );

  eachSystemOverlay = overlay: f:
    genAttrs systems (
      system:
        f {
          system = system;
          pkgs = nixpkgs.legacyPackages.${system}.extend overlay;
        }
    );

  # Map over attribute names (only)
  # dict[str, a] -> (str -> str) -> dict[str, a]
  mapAttrNames = f: set:
    listToAttrs (
      map
      (name: nameValuePair (f name) set.${name})
      (attrNames set)
    );

  # Given a prefix, and a system, flatten packages from the flake into a
  # "nested" attribute set separated by slashes. Non-recursive, only works at a
  # single level
  flattenFlake = {
    prefix,
    system,
    flake,
  }:
    mapAttrNames (name: "${prefix}/${name}") flake.packages.${system};

  # Given a system an an attrset of flakes, flatten each flake into a single
  # attrset, with "nested" keys
  flattenFlakes = system: flakes:
    concatMapAttrs (
      prefix: flake:
        flattenFlake {inherit system prefix flake;}
    )
    flakes;

  # Run a flattenFlakes, but auto-route the system parameter
  eachSystemFlattenFlakes = flakes:
    eachSystem ({system, ...}: flattenFlakes system flakes);
}
