{ pkgs, custom, ... }:

let
  updateScript = pkgs.writeShellScriptBin "update" ''
    darwin-rebuild --flake "$HOME/src/nix/cfg" switch

    # Update zsh completion cache on next start
    dumpfile="$HOME/.cache/zsh/zcompdump"
    if [ -e "$dumpfile" ]; then
      rm "$HOME/.cache/zsh/zcompdump"
    fi
  '';
in {
  # environment.systemPackages = [];
  users.users.mmazzanti.packages = (with pkgs; [
    # Terminal utilities
    bat curl fd fzf git httpie ripgrep tree vim wget jq yq
    # Networking
    nmap
    # Languages
    cargo go ruby python3
    # MacOS replacement tools
    coreutils time gnused

  ]) ++ (with custom; [
    updateScript

    # Customized tools
    direnv less nvim short-pwd zsh
  ]);

  homebrew = {
    enable = true;
    brews = [
      "ccache"
      "cmake"
      "dfu-util"
      "dtc"
      "geckodriver"
      "gnu-time"
      "ninja"
      "openssh"
      "pass"
      "qemu"
      "saulpw/vd/visidata"
      "tio"
      "wakeonlan"
    ];
    casks = [
      "1password"
      "balenaetcher"
      "discord"
      "docker"
      "element" # Matrix
      "firefox"
      "font-fira-code"
      "fujitsu-scansnap-home"
      "gcc-arm-embedded"
      "gimp"
      "google-chrome"
      "iterm2"
      "notion"
      "slack"
      "spotify"
      "ticktick"
      "utm"
      "visual-studio-code"
      "zoom"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  # Use a custom configuration.nix location.
  # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
  environment.darwinConfig = "$HOME/src/nix/cfg";

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  # nix.package = pkgs.nix;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  programs.zsh.enable = true;
  programs.zsh.promptInit = "";
  programs.zsh.enableCompletion = false;
  programs.zsh.enableBashCompletion = false;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
