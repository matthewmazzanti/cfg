{ config, pkgs, ... }: {
  imports = [ ./hardware/iota.nix ../modules ];

  config = {
    usage = {
      graphical = {
        enable = true;
        hidpi = true;
      };
    };

    nixpkgs.config.allowUnfree = true;

    # hardware.nvidia.optimus_prime = {
    #   enable = true;
    #   nvidiaBusId = "PCI:1:0:0";
    #   intelBusId = "PCI:0:2:0";
    # };

    # hardware.opengl.extraPackages = [
    #   pkgs.libGL_driver
    #   pkgs.linuxPackages.nvidia_x11.out
    # ];

    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy_470;

    services = {
      xserver = {
        # libinput.enable = true;
        videoDrivers = [ "nvidia" ];
        synaptics = {
          enable = true;
          twoFingerScroll = true;
          palmDetect = true;
        };
      };
      udev.extraHwdb = ''
        evdev:input:b0003v05ACp0262*
          KEYBOARD_KEY_70039=esc
      '';
      mbpfan.enable = true;
    };

    boot = {
      zfs.enableUnstable = true;
      supportedFilesystems = [ "zfs" ];
      kernelModules = [ "nvidia" ];
      # kernelPackages = pkgs.linuxPackages_5_14;
      # kernelPackages = pkgs.linuxPackages_latest;
    };

    networking = {
      hostName = "iota";
      hostId = "e73e73b9";
      networkmanager = {
        enable = true;
        dns = "dnsmasq";
      };
    };

    users.users.mmazzanti = {
      extraGroups = [ "networkmanager" "usb" "dialout" ];
    };

    home-manager.users.mmazzanti = {
      imports = [ ../home/modules ];

      home.packages = with pkgs; [
        xdg-user-dirs
        gopass
      ];

      services.lorri.enable = true;

      home.file = {
        ".gnupg/sshcontrol".text = ''
        '';
      };
    };

    system.stateVersion = "21.05";
  };
}
