{ pkgs, ... }:
let
  # Adapted from https://github.com/NixOS/nixpkgs/blob/ac35b104800bff9028425fec3b6e8a41de2bbfff/nixos/modules/installer/sd-card/sd-image-aarch64.nix#L23
  configTxt = pkgs.writeText "config.txt" ''
    [pi4]
    kernel=u-boot.bin
    enable_gic=1
    armstub=armstub8-gic.bin

    # Otherwise the resolution will be weird in most cases, compared to
    # what the pi3 firmware does by default.
    disable_overscan=1

    # Supported in newer board revisions
    arm_boost=1

    [all]
    # Boot in 64-bit mode.
    arm_64bit=1

    # U-Boot needs this to work, regardless of whether UART is actually used or not.
    # Look in arch/arm/mach-bcm283x/Kconfig in the U-Boot tree to see if this is still
    # a requirement in the future.
    enable_uart=1

    # Prevent the firmware from smashing the framebuffer setup done by the mainline kernel
    # when attempting to show low-voltage or overtemperature warnings.
    avoid_warnings=1
  '';

  # Adapted from https://github.com/NixOS/nixpkgs/blob/ac35b104800bff9028425fec3b6e8a41de2bbfff/nixos/modules/installer/sd-card/sd-image-aarch64.nix#L62
  # And https://github.com/NixOS/nixpkgs/pull/261857/files
  # Full list of firmware files: https://github.com/raspberrypi/firmware/tree/master/boot
  firmwareContents = pkgs.runCommand "firmwareContents" {} ''
    mkdir $out

    # Add the config
    cp ${configTxt} "$out/config.txt"

    # Copy raspberry pi 4 specific files
    fw_src=${pkgs.raspberrypifw}/share/raspberrypi/boot
    cp \
      $fw_src/bootcode.bin \
      $fw_src/fixup*.dat \
      $fw_src/start*.elf \
      $fw_src/bcm2711-rpi-4-b.dtb \
      $fw_src/bcm2711-rpi-400.dtb \
      ${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin \
      ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin \
      $out
  '';

  # Simple script to copy into the firmware directory. Might want to be smarter
  # in the future and copy directly to firmware partition
  installScript = pkgs.writeShellScriptBin "install-rpi-firmware" ''
    cp -r ${firmwareContents} ''${1:-/boot/firmware}
  '';
in {
  inherit configTxt firmwareContents installScript;
}
