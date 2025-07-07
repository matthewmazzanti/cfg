{
  self,
  inputs,
}: let
  inherit (inputs.darwin.lib) darwinSystem;

  system = "aarch64-darwin";
  flake = {
    inherit inputs;
    packages = self.packages.${system};
    lib = self.lib;
    modules = self.nixosModules;
  };
in {
  beta = darwinSystem {
    inherit system;
    specialArgs = {
      custom = flake.packages;
      flake = flake;
    };
    modules = [./beta];
  };

  delta = darwinSystem {
    inherit system;
    specialArgs = {
      custom = flake.packages;
      flake = flake;
    };
    modules = [./delta];
  };
}
