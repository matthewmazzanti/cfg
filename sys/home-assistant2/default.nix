# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ pkgs, ... }:
let
  keys = import ../../pkgs/keys;
in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware.nix
      # ./home-automation.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "home-assistant";
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  users.users.mmazzanti.openssh.authorizedKeys.keys = with keys.ssh; [
    lambda
    beta
  ];

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  environment.systemPackages = with pkgs; [
    neovim
    wget
    curl
    httpie
    ripgrep
    fd
    git
    tree
    jq
  ];

  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;
  users.users.mmazzanti = {
    isNormalUser = true;
    extraGroups = [ "wheel" "podman" "dialout" ];
  };

  security.pki.certificates = [ keys.ca.crt ];
  system.stateVersion = "24.11";
}
