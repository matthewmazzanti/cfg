# https://github.com/NixOS/nixpkgs/blob/8c00e8f75283bf91e5bfb2939ab9aa876e2cf461/nixos/modules/profiles/base.nix
{ pkgs, flake, ... }: {
  imports = [
    flake.modules.base
    ./hardware.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.initrd.systemd.enable = true;

  # Include support for various filesystems and tools to create / manipulate
  # them.
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

  # Networking
  networking.hostName = "live";
  networking.hostId = "13e69ac8"; # Really for zfs
  networking.networkmanager.enable = true;

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

    # Some networking tools.
    fuse fuse3 sshfs-fuse socat screen tcpdump

    # Hardware-related tools.
    sdparm hdparm smartmontools pciutils usbutils nvme-cli

    # My installer stuff
    sbctl fio
  ];

  # User config
  users.users.mmazzanti = {
    initialHashedPassword = ""; # Allow mmazzanti without a password
    extraGroups = ["networkmanager" "video"];
    packages = [ flake.packages."nvim/nix" ];
  };

  # Disable password for sudo
  security.sudo.wheelNeedsPassword = false;

  # Auto login as mmazzanti
  services.getty.autologinUser = "mmazzanti";

  # Allow system to stay active with closed lid, if power if attached
  services.logind.lidSwitchExternalPower = "ignore";

  system.stateVersion = "25.05";
}
