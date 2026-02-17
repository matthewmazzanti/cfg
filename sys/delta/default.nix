{
  pkgs,
  flake,
  ...
}: {
  # environment.systemPackages = [];
  users.users.mcarta.packages =
    (with pkgs; [
      # Terminal utilities
      fd
      fzf
      git
      ripgrep
      tree
      jq
      yq-go
      visidata
      # Networking
      nmap
      httpie
      wget
      curl
      nix-tree
      # coreutils
      direnv
      eza
    ])
    ++ [
      flake.packages."nvim/dev"
      flake.packages."zsh/dev"
      flake.packages.home-manager
    ];

  environment.darwinConfig = "$HOME/src/nix/cfg";

  # Auto upgrade nix package and the daemon service.
  nix.enable = true;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  programs.zsh = {
    enable = true;
    promptInit = "";
    enableCompletion = false;
    enableBashCompletion = false;
  };

  system.stateVersion = 4;
}
