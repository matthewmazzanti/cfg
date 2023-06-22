{ pkgs, custom, ... }:

let
  updateZshCache = pkgs.writeShellScriptBin "updateZshCache" ''
    zsh <<EOF
      cachedir="$HOME/.cache/zsh"
      dumpfile="$cachedir/zcompdump"
      mkdir -p "$cachedir"
      if [ -e "$dumpfile" ]; then
        rm "$dumpfile"
      fi
      autoload -Uz compinit && compinit -d "$dumpfile"
      autoload -Uz bashcompinit && bashcompinit -d "$dumpfile"
    EOF
  '';

  updateScript = pkgs.writeShellScriptBin "update" ''
    darwin-rebuild --flake "$HOME/src/nix/cfg" switch
  '';
in {
  # environment.systemPackages = [];
  users.users.mmazzanti.packages = (with pkgs; [
    # Terminal utilities
    bat curl fd fzf git httpie ripgrep tree vim wget jq yq
    # Languages
    cargo go ruby python3
    # MacOS replacement tools
    coreutils time gnused

  ]) ++ (with custom; [
    updateScript
    updateZshCache

    # Customized tools
    direnv less nvim short-pwd zsh
  ]);

  homebrew = {
    enable = true;
    brews = [
      "ccache"
      "cmake"
      "coreutils"
      "dfu-util"
      "dtc"
      "geckodriver"
      "gnu-sed"
      "gnu-time"
      "ninja"
      "nmap"
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
      "element"
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
