# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ pkgs, lib, ... }:
let
  keys = import ../../pkgs/keys;
in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware.nix
      # ./home-automation.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # Impermanence
  environment.persistence."/persist" = {
    enable = true;
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/sbctl"
      "/var/lib/systemd/coredump"
      "/var/log"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ecdsa_key"
      "/etc/ssh/ssh_host_ecdsa_key.pub"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };
  users.mutableUsers = false;
  users.users.root.hashedPasswordFile = "/persist/passwd/root";

  # Networking
  networking.hostName = "hass";
  networking.hostId = "224d13b2"; # TODO: Move with zfs settings
  networking.networkmanager.enable = true;

  # Time zone.
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

  # Select internationalization properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    # vconsole failure: https://github.com/NixOS/nixpkgs/issues/257904
    # font = "Lat2-Terminus16";
    font = "${pkgs.kbd}/share/consolefonts/Lat2-Terminus16.psfu.gz";
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
    sbctl
  ];

  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;
  users.users.mmazzanti = {
    isNormalUser = true;
    hashedPasswordFile = "/persist/passwd/mmazzanti";
    extraGroups = [ "wheel" "podman" "dialout" ];
  };

  security.pki.certificates = [ keys.ca.crt ];
  system.stateVersion = "24.11";
}
