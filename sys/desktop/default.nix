# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{ pkgs, flake, ... }: {
  imports = [
    flake.modules.base
    flake.modules.impermanence
    flake.modules.lanzaboote
    ./hardware.nix
  ];

  # Networking
  networking.hostName = "desktop";
  networking.networkmanager.enable = true;
  environment.persistence."/persist".directories = [
    "/etc/NetworkManager/system-connections"
    "/var/lib/NetworkManager"
  ];

  # Auto cleanup
  networking.hostId = "40d32d76";
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # Cap ZFS ARC at 8GiB so it doesn't compete with games for memory
  # (OpenZFS 2.2+ defaults to all RAM minus 1GiB)
  boot.kernelParams = [ "zfs.zfs_arc_max=${toString (8 * 1024 * 1024 * 1024)}" ];
  # Keep game pages resident under memory pressure
  boot.kernel.sysctl."vm.swappiness" = 10;

  # Packages
  environment.systemPackages = with pkgs; [
    firefox
    ghostty
    # flake.packages.ghostty
    wl-clipboard
    # TODO: Switch back to stable, at some point
    _1password-gui
    flake.packages.home-manager
    nixos-rebuild-ng
    direnv
    (discord.override {
      commandLineArgs = "--force-device-scale-factor=1";
    })
    eza
    btop
    # Headless FPS/frametime logger for stutter diagnosis (MANGOHUD=1 +
    # no_display in launch options); see docs/cs2-session-runbook.txt
    mangohud
  ];


  # Environment variables
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # User config
  users.users.mmazzanti = {
    extraGroups = [ "networkmanager" "gamemode" ];
    packages = [
      flake.packages."nvim/nix"
    ];
  };

  services = {
    # displayManager.gdm.enable = true;
    # desktopManager.gnome.enable = true;
    desktopManager.plasma6.enable = true;
    displayManager.sddm.enable = true;

    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = "mmazzanti";
  };

  fonts.packages = [ pkgs.fira-code ];
  services.fwupd.enable = true;

  # For video drivers and stuff
  programs.steam.enable = true;
  programs.gamescope.enable = true;

  # Per-game renice/ioprio/screensaver-inhibit, via `gamemoderun %command%`
  programs.gamemode = {
    enable = true;
    settings.general = {
      renice = 10;
      inhibit_screensaver = 1;
    };
  };

  services.power-profiles-daemon.enable = false;
  powerManagement.cpuFreqGovernor = "performance";

  # GPU performance mode
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="drm", KERNEL=="card[0-9]", DRIVERS=="amdgpu", RUN+="${pkgs.bash}/bin/bash ${./gpu_performance.sh} /sys$devpath"
  '';
}
