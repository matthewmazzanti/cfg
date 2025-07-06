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

  boot.initrd.luks.devices."aa7f83ca-dfd0-47e1-981a-66740de64eb7" = {
    device = "/dev/disk/by-uuid/aa7f83ca-dfd0-47e1-981a-66740de64eb7";
    keyFile = "/key-file:UUID=50c62c57-be39-4958-98fd-baab3d3b6d15";
    keyFileTimeout = 10;
    bypassWorkqueues = true;
    allowDiscards = true;
  };

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/000b890e-d62c-4678-a4a6-ea8f43b727a9";
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
      device = "/dev/disk/by-uuid/CD23-F450";
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

    "/var/lib/nginx" = {
      device = "root-pool/state/services/nginx";
      fsType = "zfs";
      options = ["noatime" "nodiratime" ];
    };

    "/var/lib/hass" = {
      device = "root-pool/state/services/hass";
      fsType = "zfs";
      options = ["noatime" "nodiratime" ];
    };

    "/var/lib/zwave" = {
      device = "root-pool/state/services/zwave";
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
    ''ATTRS{serial}=="010120f1fc6b4bb4ab4d7391d2fdf545bb3e6e6143450208f305b9fd806943b3e4e900000000000000000000f833a26f001c4900835581072a33742e"''
    ''RUN+="${pkgs.systemd}/bin/poweroff"''
  ];

  networking.useDHCP = true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
