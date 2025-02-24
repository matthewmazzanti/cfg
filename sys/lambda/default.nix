{ pkgs, ... }: {
  imports = [
    ./hardware.nix
    ../../old/modules
  ];

  nixpkgs.config.allowUnfree = true;
  usage = {
    graphical = {
      enable = true;
      hidpi = true;
    };
    virt.host = false;
  };

  services = {
    xserver.dpi = 168;
    udev = {
      packages = [ pkgs.dolphinEmu ];
      extraHwdb = ''
        # Naga Trinity
        mouse:usb:v1532p0067:*
            MOUSE_WHEEL_CLICK_ANGLE=30
      '';
      extraRules = ''
        # Atmel ATMega32U4
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2ff4", MODE:="0666"
        # Atmel USBKEY AT90USB1287
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2ffb", MODE:="0666"
        # Atmel ATMega32U2
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2ff0", MODE:="0666"
        # SteelSeries Rival 500
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="170e", MODE:="0666", OWNER="1000"
        # Kyria Keyboard
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="feed", ATTRS{idProduct}=="0000", MODE:="0666", OWNER="1000"
        # Naga Trinity
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="0067", MODE:="0666", OWNER="1000"
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    ddcutil
    radeontop
    radeon-profile
  ];

  programs.openvpn3.enable = true;

  boot = {
    supportedFilesystems = [ "zfs" ];
    binfmt.emulatedSystems = ["aarch64-linux"];

    tmp.cleanOnBoot = true;
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 10;
      efi.canTouchEfiVariables = true;
    };
  };

  networking = {
    hostId = "f43d79c6";
    hostName = "lambda";
    interfaces.enp5s0.wakeOnLan.enable = true;
    firewall.allowedTCPPorts = [ 8080 ];
  };

  users.users.mmazzanti = {
    extraGroups = [
      "usb"
      "dialout"
      "input"
    ];
  };



  home-manager.users.mmazzanti = {
    imports = [ ../../old/home/modules ];

    home.stateVersion = "18.09";

    home.packages = with pkgs; [
      xdg-user-dirs
      niv
      hid-listen
    ];

    services.lorri.enable = true;

    home.file = {
      ".gnupg/sshcontrol".text = ''
        62BD6A1B82D27AA64641BB11E282649654EFD6BB
      '';
    };
  };

  system.stateVersion = "20.09";
}
