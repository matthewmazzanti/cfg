{ config, pkgs, lib, ... }:

let
  updateScript = pkgs.writeShellScriptBin "update" ''
    darwin-rebuild --flake "$HOME/src/nix/cfg" switch
  '';
in {
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    updateScript
    # Terminal utilities
    vim neovim less ripgrep fd bat curl wget git tree httpie
    # Languages
    cargo go ruby python3
  ];

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

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = true;  # default shell on catalina
  # programs.fish.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}