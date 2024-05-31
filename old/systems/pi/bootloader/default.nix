{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.loader.raspberryPiCustom;

  builderUboot = import ./uboot-builder.nix {
    inherit pkgs configTxt;
  };

  builder = "${builderUboot} -g ${toString cfg.configurationLimit} -t ${timeoutStr} -c";

  blCfg = config.boot.loader;
  timeoutStr = if blCfg.timeout == null then "-1" else toString blCfg.timeout;

  optional = pkgs.lib.optionalString;

  configTxt =
    pkgs.writeText "config.txt" (''
      kernel=u-boot-rpi.bin
      enable_gic=1
      armstub=armstub8-gic.bin

      # Otherwise the resolution will be weird in most cases, compared to
      # what the pi3 firmware does by default.
      disable_overscan=1

      # Supported in newer board revisions
      arm_boost=1

      # Boot in 64-bit mode.
      arm_64bit=1

      # U-Boot needs this to work, regardless of whether UART is actually used or not.
      # Look in arch/arm/mach-bcm283x/Kconfig in the U-Boot tree to see if this is still
      # a requirement in the future.
      enable_uart=1

      # Prevent the firmware from smashing the framebuffer setup done by the mainline kernel
      # when attempting to show low-voltage or overtemperature warnings.
      avoid_warnings=1
    '' + optional (cfg.firmwareConfig != null) cfg.firmwareConfig);

in

{
  options = {

    boot.loader.raspberryPiCustom = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = lib.mdDoc ''
          Whether to create files with the system generations in
          `/boot`.
          `/boot/old` will hold files from old generations.
        '';
      };

      configurationLimit = mkOption {
        default = 20;
        example = 10;
        type = types.int;
        description = lib.mdDoc ''
          Maximum number of configurations in the boot menu.
        '';
      };

      firmwareConfig = mkOption {
        default = null;
        type = types.nullOr types.lines;
        description = lib.mdDoc ''
          Extra options that will be appended to `/boot/config.txt` file.
          For possible values, see: https://www.raspberrypi.com/documentation/computers/config_txt.html
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    system.build.installBootLoader = builder;
    system.boot.loader.id = "raspberrypi-custom";
    system.boot.loader.kernelFile = pkgs.stdenv.hostPlatform.linux-kernel.target;
  };
}
