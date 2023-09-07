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
in
{
  # environment.systemPackages = [];
  users.users.mmazzanti.packages = (with pkgs; [
    # Terminal utilities
    bat
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
    # Languages
    rustc
    cargo
    go
    ruby
    (python311.withPackages (ps: [ ps.pandas ]))
    # Misc
    pass
    tio
    wakeonlan
    # MacOS replacement tools
    coreutils
    time
    gnused
    time
    openssh
    alacritty
    helix
    clang
    poetry

    # cloud
    terraform
    awscli2
    gh
    # qemu
  ]) ++ [
    updateScript

    # Customized tools
    custom."direnv/dev"
    custom."less/dev"
    custom."nvim/dev"
    custom."short-pwd/default"
    custom."zsh/dev"
  ];

  homebrew = {
    enable = true;
    brews = [
      "ccache"
      "cmake"
      "dfu-util"
      "dtc" # Device tree compiler, zephyr
      "ninja"
      "qemu"
      "libvirt"
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
      "google-drive"
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
  nix.buildMachines = [{
    sshUser = "build";
    hostName = "192.168.65.2";
    systems = [ "x86_64-linux" "aarch64-linux" ];
    protocol = "ssh-ng";
    maxJobs = 8;
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUFzRzU1Q1hYeDFTczh4dlRYRk8ycnJpejh6SlVRZ0dhMXZ2ZDVhZUhHRE4K";
  }];
  nix.distributedBuilds = true;
  # optional, useful when the builder has a faster internet connection than yours
  nix.extraOptions = ''
    builders-use-substitutes = true
    experimental-features = nix-command flakes
  '';
  nix.settings.trusted-users = [ "mmazzanti" ];

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
