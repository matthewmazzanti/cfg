nixpkgs: let
  inherit (nixpkgs.lib) genAttrs importJSON;
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

  keys = import ./keys;
  images = importJSON ./images.json;
}
