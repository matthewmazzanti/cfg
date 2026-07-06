{
  config,
  lib,
  flake,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  boot.initrd = let
    luksDevices = [ "8da62c32-7525-4ce6-a493-b4fc149e5421" ];
  in {
    availableKernelModules = [
      "xhci_pci"
      "nvme"
      "usb_storage"
      "usbhid"
      "sd_mod"
    ];

    supportedFilesystems = [];
    kernelModules = [];

    luks.devices = lib.genAttrs luksDevices (uuid: {
      device = "/dev/disk/by-uuid/${uuid}";
      bypassWorkqueues = true;
      allowDiscards = true;
    });

    systemd.services = flake.lib.zfsImportAfterLuks {
      inherit luksDevices;
      zfsPools = [ "root-pool" ];
    };
  };

  boot.supportedFilesystems = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/2904eaf4-2c48-4a01-a63a-78b02b135c7e";
      randomEncryption.enable = true;
      randomEncryption.allowDiscards = true;
    }
  ];

  fileSystems = {
    "/" = {
      device = "root-pool/local/root";
      fsType = "zfs";
      options = ["noatime" "nodiratime" ];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/F0C3-BEFC";
      fsType = "vfat";
      # Systemd "Security hole" warnings:
      # https://github.com/NixOS/nixpkgs/issues/279362
      options = ["noatime" "nodiratime" "fmask=0077" "dmask=0077"];
    };

    "/nix" = {
      device = "root-pool/local/nix";
      fsType = "zfs";
      options = ["noatime" "nodiratime" ];
    };

    "/persist" = {
      device = "root-pool/state/persist";
      fsType = "zfs";
      options = ["noatime" "nodiratime" ];
      neededForBoot = true;
    };

    "/home" = {
      device = "root-pool/state/home";
      fsType = "zfs";
      options = ["noatime" "nodiratime" ];
    };
  };

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
