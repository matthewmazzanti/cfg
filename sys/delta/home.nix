{ flake, ... }: {
  home = {
    username = "mcarta";
    homeDirectory = "/Users/mcarta";

    file.".config/ghostty/config".source = flake.packages."ghostty/config".override {
      extraConfig = { command = "/etc/profiles/per-user/mcarta/bin/zsh"; };
    };
    # TODO: Wrapper
    file.".config/direnv/lib/nix-direnv.sh".source = "${flake.packages.nix-direnv}/share/nix-direnv/direnvrc";

    # Match this to the version of Home Manager you're using
    stateVersion = "24.05";
  };
}
