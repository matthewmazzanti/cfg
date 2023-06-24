{ pkgs, custom, ... }:

let
  updateScript = pkgs.writeShellScriptBin "update" ''
    darwin-rebuild --flake "$HOME/src/nix/cfg" switch

    # Update zsh completion cache on next start
    dumpfile="$HOME/.cache/zsh/zcompdump"
    if [ -e "$dumpfile" ]; then
      rm "$dumpfile"
    fi
  '';
in {
  # environment.systemPackages = [];
  users.users.mmazzanti.packages = (with pkgs; [
    # Terminal utilities
    bat fd fzf git ripgrep tree vim jq yq visidata
    # Networking
    nmap httpie wget curl
    # Languages
    rustc cargo go ruby python3
    # Misc
    pass tio wakeonlan
    # MacOS replacement tools
    coreutils time gnused time openssh
    alacritty
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
      "dtc" # Device tree compiler, zephyr
      "ninja"
      "qemu"
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

  programs.zsh = {
    enable = true;
    promptInit = "";
    enableCompletion = false;
    enableBashCompletion = false;
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
