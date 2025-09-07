{
  pkgs,
  flake,
  ...
}: let
  updateScript = pkgs.writeShellScriptBin "update" ''
    set -e
    darwin-rebuild --flake "$HOME/src/nix/cfg#delta" switch

    # Update zsh completion cache on next start
    dumpfile="$HOME/.cache/zsh/zcompdump"
    if [ -e "$dumpfile" ]; then
      rm "$dumpfile"
    fi
  '';
in {
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
      coreutils
    ])
    ++ [
      updateScript
      flake.packages."nvim/dev"
      flake.packages."short-pwd/default"
      flake.packages."zsh/dev"
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
