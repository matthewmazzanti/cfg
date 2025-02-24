{ pkgs, configTxt }:

let
  uboot = pkgs.ubootRaspberryPi4_64bit;

  extlinuxConfNix = pkgs.path + "/nixos/modules/system/boot/loader/generic-extlinux-compatible/extlinux-conf-builder.nix";
  extlinuxConfBuilder = import extlinuxConfNix {
    pkgs = pkgs.buildPackages;
  };
in
pkgs.substituteAll {
  src = ./uboot-builder.sh;
  isExecutable = true;
  inherit (pkgs) bash;
  path = [pkgs.coreutils pkgs.gnused pkgs.gnugrep];
  firmware = pkgs.raspberrypifw;
  armstubs = pkgs.raspberrypi-armstubs;
  inherit uboot;
  inherit configTxt;
  inherit extlinuxConfBuilder;
}

