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

  nixpkgs.config.allowUnfree = true;

  # Networking
  networking.hostName = "framework";
  networking.networkmanager.enable = true;
  environment.persistence."/persist".directories = [
    "/etc/NetworkManager/system-connections"
    "/var/lib/NetworkManager"
  ];

  # Auto cleanup
  networking.hostId = "6ed57933";
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # Packages
  environment.systemPackages = with pkgs; [
    firefox
    # TODO: Switch back to stable, at some point
    _1password-gui-beta
  ];

  # Environment variables
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # User config
  users.users.mmazzanti = {
    extraGroups = [ "networkmanager" ];
    packages = [ flake.packages."nvim/nix" ];
  };

  # Auto login as mmazzanti
  # services.getty.autologinUser = "mmazzanti";
  # services.getty.autologinOnce = true;

  services = {
    displayManager.gdm.enable = true;
    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = "mmazzanti";
    desktopManager.gnome.enable = true;
  };
}
