# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{ pkgs, flake, ... }: {
  imports = [
    flake.modules.base
    flake.modules.impermanence
    flake.modules.lanzaboote
    flake.modules.hardware.framework-13-7040-amd
    ./hardware.nix
    # ./nrf.nix
  ];

  # Networking
  networking.hostName = "framework";
  networking.networkmanager.enable = true;
  environment.persistence."/persist".directories = [
    "/etc/NetworkManager/system-connections"
    "/var/lib/NetworkManager"
    "/var/lib/fprint"
  ];

  # Auto cleanup
  networking.hostId = "6ed57933";
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # Packages
  environment.systemPackages = with pkgs; [
    wl-clipboard
    nixos-rebuild-ng
    firefox
  ];

  # Environment variables
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # User config
  users.users.mmazzanti = {
    extraGroups = [ "networkmanager" ];
    packages = with pkgs; [
      flake.packages."nvim/dev"
      flake.packages."scan/client" # `scan <name.pdf>`: scan on print, copy back
      mpv # Tui movie player
      todoist-electron # TODO list
      obsidian
      ghostty
      _1password-gui
      _1password-cli
      spotify
      element-desktop
      claude-code
      proton-pass
      protonmail-desktop
    ];
  };

  # Graphical settings
  services = {
    displayManager.gdm.enable = true;
    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = "mmazzanti";
    desktopManager.gnome.enable = true;
  };
  fonts.packages = [ pkgs.fira-code ];

  # Podman settings
  virtualisation.podman.enable = true;
  users.users.mmazzanti.autoSubUidGidRange = true;

  # Enable finger print scanner
  services.fprintd.enable = true;
  # Enable non-nix binaries, like uv
  programs.nix-ld.enable = true;

  # Gaming
  programs.steam.enable = true;
}
