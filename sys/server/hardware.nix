{ config, lib, pkgs, ... }: {
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.supportedFilesystems = ["ext4"];
  boot.initrd.kernelModules = [];
  boot.supportedFilesystems = ["ext4"];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  boot.initrd.luks.devices."5934f569-b4a3-492e-9c5c-6429939a4082" = {
    device = "/dev/disk/by-uuid/5934f569-b4a3-492e-9c5c-6429939a4082";
    keyFile = "/key-file:UUID=f893b93f-b2a7-4de9-9650-71e6d850102d";
    keyFileTimeout = 10;
    bypassWorkqueues = true;
    allowDiscards = true;
  };

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/bd9314f2-1074-428d-a1ed-7ab0d5fd36fe";
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
      device = "/dev/disk/by-uuid/D01B-0C25";
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

    "/srv/share/media" = {
      device = "data-pool/share/media";
      fsType = "zfs";
      options = ["noatime" "nodiratime" ];
    };

    "/srv/share/documents" = {
      device = "data-pool/share/documents";
      fsType = "zfs";
      options = ["noatime" "nodiratime" ];
    };
  };

  services.udev.path = [pkgs.systemd];
  services.udev.extraRules = lib.strings.concatStringsSep ", " [
    ''ACTION=="remove"''
    ''SUBSYSTEMS=="usb"''
    ''DRIVERS=="usb"''
    ''ATTRS{idProduct}=="5583"''
    ''ATTRS{idVendor}=="0781"''
    ''ATTRS{serial}=="01017529487ef0c9a1ba96ca2d7456553b31c2036f1da2f1b6eb04fe662b0413d8e40000000000000000000084629741001e5a00835581072a336cdf"''
    ''RUN+="${pkgs.systemd}/bin/poweroff"''
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
