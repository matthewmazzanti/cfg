{
  config,
  lib,
  flake,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd = let
    luksDevices = [ "90581c5c-2e2b-4c0e-81fe-1310536bd256" ];
  in {
    availableKernelModules = ["xhci_pci" "nvme" "usb_storage" "usbhid" "sd_mod"];
    kernelModules = [];

    luks.devices = lib.genAttrs luksDevices (uuid: {
      device = "/dev/disk/by-uuid/${uuid}";
      bypassWorkqueues = true;
    });

    # ext4 root -- no zfsPools, so only the console-setup-before-unlock ordering.
    systemd.services = flake.lib.cryptOrdering { inherit luksDevices; };
  };

  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/f56ebe71-95cc-4e1c-b532-ffb24db99cb9";
    fsType = "ext4";
    options = ["noatime" "nodiratime"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/F716-67B8";
    fsType = "vfat";
    options = ["noatime" "nodiratime" "fmask=0022" "dmask=0022"];
  };

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
