{ config, lib, utils, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd = let
    luksUuid = "0050d616-0fd0-40da-8760-e14cc7f108f6";
    cryptsetupUnit = "systemd-cryptsetup@${utils.escapeSystemdPath luksUuid}.service";
  in {
    availableKernelModules = [
      "xhci_pci"
      "nvme"
      "usb_storage"
      "usbhid"
      "sd_mod"
    ];

    supportedFilesystems = [ ];
    kernelModules = [ ];

    luks.devices.${luksUuid} = {
      device = "/dev/disk/by-uuid/${luksUuid}";
      bypassWorkqueues = true;
      allowDiscards = true;
    };

    systemd.services."zfs-import-root-pool" = {
      after = [ cryptsetupUnit ];
      requires = [ cryptsetupUnit ];
    };
  };

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/f3c53612-4a4f-4d5c-a7ee-71859d367c99";
      randomEncryption.enable = true;
      randomEncryption.allowDiscards = true;
    }
  ];

  fileSystems = {
    "/" = {
      device = "root-pool/local/root";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/542F-DBEC";
      fsType = "vfat";
      options = [ "noatime" "nodiratime" "fmask=0077" "dmask=0077" ];
    };

    "/nix" = {
      device = "root-pool/local/nix";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };

    "/persist" = {
      device = "root-pool/state/persist";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
      neededForBoot = true;
    };

    "/home" = {
      device = "root-pool/state/home";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };
  };

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
