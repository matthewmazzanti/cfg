{ pkgs, ... }: {
  home = {
  username = "mmazzanti";
  homeDirectory = "/home/mmazzanti";

  packages = [ pkgs.eza ];

  # Match this to the version of Home Manager you're using
  stateVersion = "24.05";
  };
}
