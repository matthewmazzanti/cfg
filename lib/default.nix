nixpkgs: let
  inherit (nixpkgs.lib) genAttrs importJSON;
  # escapeSystemdPath lives in nixos/lib/utils.nix, which wants { lib, config,
  # pkgs }. The escape helper only touches lib, and Nix is lazy, so throwaway
  # config/pkgs let us use the canonical function without a NixOS eval.
  inherit
    (import "${nixpkgs}/nixos/lib/utils.nix" {
      inherit (nixpkgs) lib;
      config = {};
      pkgs = {};
    })
    escapeSystemdPath
    ;
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

  # Create a simple dev shell for each system
  # TODOS
  #   - Make the callpackage and other calls simpler, pull out into other things
  #   - Document here and in the nix script purpose and stuff
  eachSystemShell = inputs:
    eachSystem (
      { pkgs, ... } @ systemInputs:
        (pkgs.callPackage (import ./mkNakedShell.nix) {}) (inputs systemInputs)
    );

  # Factory linking a host's LUKS unlock into the initrd boot ordering.
  cryptOrdering = import ./cryptOrdering.nix {
    inherit (nixpkgs) lib;
    inherit escapeSystemdPath;
  };

  keys = import ./keys;
  images = importJSON ./images.json;
  # Kernel/zfs package-attr pins, bumped forward-only by `bump-kernel`.
  pins = importJSON ./pins.json;
  # zfs x linux compatibility matrix per system, read by bin/bump-kernel via
  # `.#lib.zfsKernelMatrix.<system>` so it can eval purely (no --impure). Defined
  # for every system -- the projection is guarded and evals everywhere; non-linux
  # results are irrelevant and unread (bump-kernel only queries the linux host).
  zfsKernelMatrix = eachSystem ({ pkgs, ... }:
    import ./zfs-kernel-matrix.nix { inherit pkgs; });
}
