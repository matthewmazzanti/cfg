# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  pkgs,
  flake,
  ...
}: let
  keys = import ../../pkgs/keys;
in {
  imports = [
    flake.inputs.impermanence.nixosModules.impermanence
    flake.inputs.lanzaboote.nixosModules.lanzaboote
    ./hardware.nix
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
      "/var/db/sudo/lectured"
      "/var/lib/NetworkManager"
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

  # Networking
  networking.hostName = "hass";
  networking.hostId = "224d13b2";
  networking.networkmanager.enable = true;

  # Console stuff
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # Time zone.
  time.timeZone = "America/New_York";

  # Auto cleanup
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 180d";
  nix.optimise.automatic = true;
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

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

  # Packages
  environment.systemPackages = with pkgs; [
    flake.packages."nvim/root"
    # Http stuff
    wget
    curl
    httpie
    # Misc utils
    ripgrep
    fd
    git
    tree
    jq
    # Secure boot
    sbctl

    # Installation/debug utils
    e2fsprogs
    gptfdisk
    usbutils

    # Compression
    unzip
    zip

    python3
    # Install stuff, remove later
    fio
  ];

  # User config
  users.mutableUsers = false;
  users.users.mmazzanti = {
    isNormalUser = true;
    hashedPasswordFile = "/persist/passwd/mmazzanti";
    extraGroups = ["wheel" "networkmanager" "podman" "dialout"];
    packages = [ flake.packages."nvim/nix" ];
  };

  # Enable zsh
  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;

  # Trust my CA
  security.pki.certificates = [keys.ca.crt];

  # Nix configuration
  nix.extraOptions = "experimental-features = nix-command flakes";

  system.stateVersion = "24.11";
}
