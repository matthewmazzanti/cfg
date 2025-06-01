{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.initrd.luks.devices."90581c5c-2e2b-4c0e-81fe-1310536bd256" = {
    device = "/dev/disk/by-uuid/807c816a-cec5-4e2a-b7e1-e3034af7b6c7";
    bypassWorkqueues = true;
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/f56ebe71-95cc-4e1c-b532-ffb24db99cb9";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/F716-67B8";
    fsType = "vfat";
    options = [ "noatime" "fmask=0022" "dmask=0022" ];
  };

  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
