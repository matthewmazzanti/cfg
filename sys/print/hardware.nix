{ config, lib, pkgs, flake, ... }: {
  boot.initrd = let
    luksDevices = [ "c74b3bec-0c38-4e8f-a2b0-bf89fa234b1a" ];
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
      keyFile = "/key-file:UUID=800e8fd9-22c6-4879-bbaf-99f506722cf9";
      keyFileTimeout = 10;
      bypassWorkqueues = true;
      allowDiscards = true;
    });

    systemd.services = flake.lib.cryptOrdering {
      inherit luksDevices;
      zfsPools = [ "root-pool" ];
    };
  };

  boot.supportedFilesystems = ["ext4"];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/58570ec6-bec4-4b1c-8dd6-4d037dddd15e";
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
      device = "/dev/disk/by-uuid/2413-6615";
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

  services.udev.path = [pkgs.systemd];
  services.udev.extraRules = lib.strings.concatStringsSep ", " [
    ''ACTION=="remove"''
    ''SUBSYSTEMS=="usb"''
    ''DRIVERS=="usb"''
    ''ATTRS{idProduct}=="5583"''
    ''ATTRS{idVendor}=="0781"''
    ''ATTRS{serial}=="04019fcd9c4e79ca44691256512632c8626a90f14e01b7093716c05a775fdfdf29450000000000000000000015af046c00821b1883558107a8ac7d66"''
    ''RUN+="${pkgs.systemd}/bin/poweroff"''
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
