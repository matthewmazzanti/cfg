{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "ext4"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.initrd.systemd.enable = true;

  boot.initrd.luks.devices.root-crypt = {
    device = "/dev/disk/by-uuid/8039de4e-62d8-48e6-947a-0595c3113b4e";
    keyFile = "/key-file:UUID=99bafd25-76c5-4eaf-9704-6e96ddf68c47";
    keyFileTimeout = 10;
    allowDiscards = true;
  };

  boot.initrd.systemd.services.rollback-root = {
    description = "Rollback root filesystem to blank state on boot";
    wantedBy = [ "initrd.target" ];
    before = [ "sysroot.mount" ];
    after = [ "zfs-import-root-pool.service" ];
    path = with pkgs; [ zfs ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = "zfs rollback -r root-pool/local/root@blank";
  };

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/1a5b27ae-dece-4988-9ca5-a9c06ad5201d";
      randomEncryption.enable = true;
    }
  ];

  fileSystems = {
    "/" = {
      device = "root-pool/local/root";
      fsType = "zfs";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/4A36-E229";
      fsType = "vfat";
      # Systemd "Security hole" warnings:
      # https://github.com/NixOS/nixpkgs/issues/279362
      options = [ "fmask=0077" "dmask=0077" ];
    };

    "/nix" = {
      device = "root-pool/local/nix";
      fsType = "zfs";
    };

    "/persist" = {
      device = "root-pool/state/persist";
      fsType = "zfs";
      neededForBoot = true;
    };

    "/home" = {
      device = "root-pool/state/home";
      fsType = "zfs";
    };
  };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted
  # networking (the default) this is the recommended approach. When using
  # systemd-networkd it's still possible to use this option, but it's
  # recommended to use it in conjunction with explicit per-interface
  # declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
