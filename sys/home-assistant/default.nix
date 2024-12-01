{ config, lib, pkgs, ... }:

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
  activationScript = ''
    function installRaspberryPiFirmware() {
      local dst='/boot/firmware'
      local fw_src=${pkgs.raspberrypifw}/share/raspberrypi/boot

      # Add the config
      cp ${configTxt} "$dst/config.txt"

      # Copy baseline raspberry pi files
      cp \
        "$fw_src/bootcode.bin" \
        "$fw_src"/fixup*.dat \
        "$fw_src"/start*.elf \
        "$dst"

      # Copy raspberry pi 4 specific files
      cp \
        ${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin \
        ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin \
        "$fw_src/bcm2711-rpi-4-b.dtb" \
        "$fw_src/bcm2711-rpi-400.dtb" \
        "$fw_src/bcm2711-rpi-cm4.dtb" \
        "$fw_src/bcm2711-rpi-cm4s.dtb" \
        "$dst"
    }

    installRaspberryPiFirmware()
  '';
in {
  imports = [ ./hardware.nix ];

  system.activationScripts.raspberrypiFirmware = activationScript;

  nix.extraOptions = "experimental-features = nix-command flakes";

  networking.hostName = "home-assistant";

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  environment.systemPackages = with pkgs; [
    neovim
    wget
    curl
    httpie
    ripgrep
    fd
    git
    # Raspberry pi specific stuff
    libraspberrypi
    raspberrypi-eeprom
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;

  users.users.mmazzanti = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "dialout" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4h5HZCnD2uFkpb8Z/pPQKXrtdV5YU3DG1w+9rOyddy mmazzanti@beta.xi"
    ];
  };

  system.stateVersion = "25.05";
}
