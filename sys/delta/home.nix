{ flake, ... }: {
  home = {
    username = "mcarta";
    homeDirectory = "/Users/mcarta";

    # TODO: Wrapper
    file.".config/ghostty/config".source = ./config/ghostty.config;
    # TODO: Wrapper
    file.".config/direnv/lib/nix-direnv.sh".source = "${flake.packages.nix-direnv}/share/nix-direnv/direnvrc";

    # Match this to the version of Home Manager you're using
    stateVersion = "24.05";
  };
}
