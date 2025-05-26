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
    device = "/dev/disk/by-uuid/547d874f-c18a-4519-b52b-0969dc999cc3";
    keyFile = "/key-file:UUID=e96b6967-aacd-4f25-8256-664ae143646f";
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
      device = "/dev/disk/by-partuuid/8d065161-122d-4919-af6b-95a15b2954a4";
      randomEncryption.enable = true;
    }
  ];

  fileSystems = {
    "/" = {
      device = "root-pool/local/root";
      fsType = "zfs";
      options = [ "noatime" ];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/E745-7031";
      fsType = "vfat";
      # Systemd "Security hole" warnings:
      # https://github.com/NixOS/nixpkgs/issues/279362
      options = [ "noatime" "fmask=0077" "dmask=0077" ];
    };

    "/nix" = {
      device = "root-pool/local/nix";
      fsType = "zfs";
      options = [ "noatime" ];
    };

    "/persist" = {
      device = "root-pool/state/persist";
      fsType = "zfs";
      options = [ "noatime" ];
      neededForBoot = true;
    };

    "/home" = {
      device = "root-pool/state/home";
      fsType = "zfs";
      options = [ "noatime" ];
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
