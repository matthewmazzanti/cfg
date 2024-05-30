{
  pkgs,
  custom,
  ...
}: let
  updateScript = pkgs.writeShellScriptBin "update" ''
    set -e
    darwin-rebuild --flake "$HOME/src/nix/cfg" switch

    # Update zsh completion cache on next start
    dumpfile="$HOME/.cache/zsh/zcompdump"
    if [ -e "$dumpfile" ]; then
      rm "$dumpfile"
    fi
  '';
in {
  # environment.systemPackages = [];
  users.users.matthew-carta.packages =
    (with pkgs; [
      # Terminal utilities
      fd
      fzf
      git
      ripgrep
      tree
      vim
      jq
      yq
      visidata
      # Networking
      nmap
      httpie
      wget
      curl
      nix-tree
    ])
    ++ [
      updateScript
      custom."nvim/web"
      custom."short-pwd/default"
      custom."zsh/dev"
      custom."direnv/dev"
    ];

  environment.darwinConfig = "$HOME/src/nix/cfg";

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
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
