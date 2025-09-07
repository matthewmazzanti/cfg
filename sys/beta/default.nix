{
  pkgs,
  lib,
  custom,
  flake,
  ...
}: let
  inherit (lib) escapeShellArg;

  hostname = "beta";

  updateScript = pkgs.writeShellScriptBin "update" ''
    set -euo pipefail

    can_update() {
      local dir="$1"

      if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Not a Git repository: $dir"
        return 1
      fi

      local branch="$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo "detached")"
      if [[ "$branch" != "dev" ]]; then
        echo "Not on dev branch (currently on '$branch') in $dir"
        return 1
      fi

      if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
        echo "Repository at $dir is not clean"
        return 1
      fi

      return 0
    }

    cfg="''${1:-"$HOME/src/nix/cfg"}"
    if ! can_update "$cfg"; then
      exit 1
    fi

    brew update
    nix flake update --flake "$cfg#${escapeShellArg hostname}"
  '';

  cleanScript = pkgs.writeShellScriptBin "clean" ''
    set -euo pipefail

    # Remove dead links from brew
    brew autoremove
    brew cleanup

    # Update zsh completion cache on next start
    cache="$HOME/.cache/zsh/zcompdump"
    if [[ -e "$cache" ]]; then rm "$cache"; fi

    # Clear neovim luac compilation cache
    cache="$HOME/.cache/nvim/luac"
    if [[ -d "$cache" ]]; then rm -r "$cache"; fi
  '';

  upgradeScript = pkgs.writeShellScriptBin "upgrade" ''
    set -eou pipefail
    cfg="''${1:-"$HOME/src/nix/cfg"}"
    sudo darwin-rebuild --flake "$cfg#${escapeShellArg hostname}" switch
    brew upgrade
  '';
in {
  # environment.systemPackages = [];
  system.primaryUser = "mmazzanti";
  users.users.mmazzanti.packages =
    (with pkgs; [
      # Terminal utilities
      bat fd fzf git ripgrep tree jq yq visidata htop unixtools.watch direnv
      # Networking
      nmap httpie wget curl
      # Languages
      rustc cargo go ruby python313 uv nodejs

      # Misc
      pass tio wakeonlan openssh pv m1ddc
      # MacOS replacement tools
      coreutils time gnused time openssh helix clang

      # cloud
      awscli2 gh gh-copilot nodejs
      # qemu
      tmux screen
      # nix
      nix-tree
    ])
    ++ [
      updateScript
      upgradeScript
      cleanScript

      # Customized tools
      flake.packages."less/dev"
      flake.packages."nvim/dev"
      flake.packages."nvim/ai"
      flake.packages."short-pwd/default"
      flake.packages."zsh/dev"
    ];

  homebrew = {
    enable = true;
    global.autoUpdate = false;
    brews = [
      "ccache"
      "cmake"
      "dfu-util"
      "dtc" # Device tree compiler, zephyr
      "esphome"
      "esptool"
      "geckodriver"
      "irssi"
      "libvirt"
      "minicom"
      "ninja"
      "ocrmypdf"
      "openjdk"
      "openvino"
      "pkgconf"
      "pass"
      "platformio"
      "qemu"
      "speedtest-cli"
      "weasyprint"
    ];
    casks = [
      "1password"
      "1password-cli"
      "android-platform-tools"
      "balenaetcher"
      "discord"
      "docker"
      "element"
      "firefox"
      "font-fira-code"
      "freecad"
      "ftdi-vcp-driver"
      "fujitsu-scansnap-home"
      "gcc-arm-embedded"
      "gimp"
      "google-chrome"
      "google-drive"
      "ghostty"
      "inkscape"
      "iterm2"
      "keycastr"
      "logitune"
      "macfuse"
      "mixxx"
      "notion"
      "obs"
      "quicken"
      "raspberry-pi-imager"
      "slack"
      "spotify"
      "tailscale"
      "ticktick"
      "todoist"
      "ubiquiti-unifi-controller"
      "utm"
      "visual-studio-code"
      "zoom"
    ];
  };

  networking.hostName = hostname;

  # Auto upgrade nix package and the daemon service.
  # optional, useful when the builder has a faster internet connection than yours
  nix.extraOptions = ''
    builders-use-substitutes = true
    experimental-features = nix-command flakes
  '';
  nix.settings.trusted-users = ["mmazzanti"];

  programs.zsh = {
    enable = true;
    promptInit = "";
    enableCompletion = false;
    enableBashCompletion = false;
  };

  security.pki.certificates = [ flake.lib.keys.ca.crt ];

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
