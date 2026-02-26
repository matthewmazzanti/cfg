{ flake, ... }: {
  home = {
    username = "mmazzanti";
    homeDirectory = "/home/mmazzanti";

    file.".config/ghostty/config".source = flake.packages."ghostty/config";

    # Match this to the version of Home Manager you're using
    stateVersion = "24.05";
  };
}
