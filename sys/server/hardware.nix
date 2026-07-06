{ config, lib, pkgs, flake, ... }: {
  boot.initrd = let
    keyFile = "/key-file:UUID=f893b93f-b2a7-4de9-9650-71e6d850102d";
    # Only this device enables TRIM/discard passthrough.
    ssdUuid = "5934f569-b4a3-492e-9c5c-6429939a4082";
    luksDevices = [
      ssdUuid
      "e0c6ed81-51f8-423c-ba9f-2873837a91e7"
      "b2bcfa53-8f2e-47b2-b7d7-3a68f2a13660"
      "26713afa-4b9b-41b3-be58-8ae760a31ca9"
      "61a8a2ef-77e7-41bd-9448-8e4404a040e6"
    ];
  in {
    availableKernelModules = [
      "xhci_pci"
      "nvme"
      "usb_storage"
      "usbhid"
      "sd_mod"
    ];
    supportedFilesystems = ["ext4"];
    kernelModules = [];

    luks.devices = lib.genAttrs luksDevices (uuid: {
      device = "/dev/disk/by-uuid/${uuid}";
      inherit keyFile;
      keyFileTimeout = 10;
      bypassWorkqueues = true;
      allowDiscards = uuid == ssdUuid;
    });

    systemd.services = flake.lib.zfsImportAfterLuks {
      inherit luksDevices;
      zfsPools = [ "root-pool" ];
    };
  };

  boot.supportedFilesystems = ["ext4"];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/19010be8-1da1-4dd9-bf8d-12cfdffe39f6";
      randomEncryption.enable = true;
      randomEncryption.allowDiscards = true;
    }
  ];

  boot.zfs.pools = {
    "root-pool".devNodes = "/dev/mapper";
    "data-pool".devNodes = "/dev/mapper";
  };

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
