{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.initrd.systemd.enable = true;

  boot.initrd.luks.devices.root-crypt = {
    device = "/dev/disk/by-uuid/a00ecc43-a330-4b40-bb1d-f5d2adb3a738";
    keyFile = "/key-file:UUID=918e8304-57ac-408d-bb0c-835e895db539";
    keyFileTimeout = 10;
    allowDiscards = true;
  };

  boot.initrd.systemd.services.rollback = {
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
      device = "/dev/disk/by-partuuid/cc86d193-c3c8-417c-9147-6067b0924b76";
      randomEncryption.enable = true;
    }
  ];

  fileSystems = {
    "/" = {
      device = "root-pool";
      fsType = "zfs";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/CD37-C063";
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

  environment.persistence."/persist" = {
    enable = true;
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/sbctl"
      "/var/lib/systemd/coredump"
      "/var/log"
    ];
    files = [
      "/etc/machine-id"
      "/etc/shadow"
      "/etc/ssh/ssh_host_ecdsa_key"
      "/etc/ssh/ssh_host_ecdsa_key.pub"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
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
