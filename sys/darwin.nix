{
  darwin,
  packages,
}: let
  system = "aarch64-darwin";
in {
  beta = darwin.lib.darwinSystem {
    inherit system;
    specialArgs.custom = packages;
    modules = [./sys/beta];
  };

  delta = darwin.lib.darwinSystem {
    inherit system;
    specialArgs.custom = packages;
    modules = [./sys/delta];
  };
}
