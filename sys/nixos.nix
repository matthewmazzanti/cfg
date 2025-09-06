{
  self,
  inputs,
}: let
  system = "x86_64-linux";

  nixosSystem = inputs.nixpkgs.lib.nixosSystem;

  flake = {
    inherit inputs;
    packages = self.packages.${system};
    lib = self.lib;
    modules = self.nixosModules;
  };
in {
  framework = nixosSystem {
    inherit system;
    specialArgs.flake = flake;
    modules = [ ./framework ];
  };

  server = nixosSystem {
    inherit system;
    specialArgs.flake = flake;
    modules = [ ./server ];
  };

  ha = nixosSystem {
    inherit system;
    specialArgs.flake = flake;
    modules = [ ./ha ];
  };

  print = nixosSystem {
    inherit system;
    specialArgs.flake = flake;
    modules = [ ./print ];
  };

  live = nixosSystem {
    inherit system;
    specialArgs.flake = flake;
    modules = [ ./live ];
  };
}
