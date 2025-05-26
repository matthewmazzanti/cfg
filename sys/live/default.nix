# https://github.com/NixOS/nixpkgs/blob/8c00e8f75283bf91e5bfb2939ab9aa876e2cf461/nixos/modules/profiles/base.nix
{ config, lib, pkgs, ... }:
let
  keys = import ../../pkgs/keys;
in {
  boot.loader.systemd-boot.enable = true;
  boot.initrd.systemd.enable = true;

  # Include support for various filesystems and tools to create / manipulate them.
  boot.supportedFilesystems = [
    "ext3"
    "ext4"
    "btrfs"
    "cifs"
    "f2fs"
    "ntfs"
    "vfat"
    "xfs"
    "zfs"
  ];

  # Console stuff
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # Time zone.
  time.timeZone = "America/New_York";

  # Networking
  networking.hostName = "live";
  networking.hostId = "13e69ac8"; # Really for zfs
  networking.networkmanager.enable = true;

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

  # Include some utilities that are useful for installing or repairing
  # the system.
  environment.systemPackages = with pkgs; [
    testdisk # useful for repairing boot problems
    ms-sys # for writing Microsoft boot sectors / MBRs
    efibootmgr
    efivar
    gptfdisk
    ddrescue
    ccrypt
    cryptsetup # needed for dm-crypt volumes

    # Some text editors.
    neovim

    # Some networking tools.
    fuse fuse3 sshfs-fuse socat screen tcpdump

    # Hardware-related tools.
    sdparm hdparm smartmontools pciutils usbutils nvme-cli

    # Some compression/archiver tools.
    unzip zip

    # Http stuff
    wget curl
    # Misc utils
    ripgrep fd git tree jq
  ];

  # User config
  users.mutableUsers = false;
  users.users.root.initialHashedPassword = ""; # Allow root without password
  users.users.mmazzanti = {
    isNormalUser = true;
    initialHashedPassword = ""; # Allow mmazzanti without a password
    extraGroups = [ "wheel" "networkmanager" "video"];
  };

  # Auto login as mmazzanti
  services.getty.autologinUser = "mmazzanti";

  # Enable zsh
  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;

  # Trust my CA
  security.pki.certificates = [ keys.ca.crt ];

  system.stateVersion = "25.05";
}
