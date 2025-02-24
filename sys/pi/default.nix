{ pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./home-automation.nix
    # TODO: Clean this up
    ../../old/modules
  ];

  usage = {
    graphical = {
      enable = false;
      hidpi = true;
    };
    virt.host = false;
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_rpi4;
    initrd.availableKernelModules = [
      "usbhid"
      "usb_storage"
      "vc4"
      "pcie_brcmstb"
      "reset-raspberrypi"
    ];
    loader = {
      grub.enable = false;
      raspberryPi = {
        enable = true;
        version = 4;
      };
    };
  };

  networking.hostName = "pi";

  users.users.mmazzanti = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "dialout" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4h5HZCnD2uFkpb8Z/pPQKXrtdV5YU3DG1w+9rOyddy mmazzanti@beta.xi"
    ];
  };

  environment.systemPackages = with pkgs; [
    neovim
    wget
    curl
    httpie
    ripgrep
    fd
    bat
    raspberrypi-eeprom
    git
    minicom
    wol
  ];

  services.openssh.enable = true;

  systemd = {
    timers.startup-timer = {
      wantedBy = [ "timers.target" ];
      partOf = [ "startup-timer.service" ];
      timerConfig.OnCalendar = "*-*-* 07:30:00";
    };

    # Lambda mac address
    # ${pkgs.wol}/bin/wol fc:34:97:a1:5d:fa -v
    services.startup-timer = {
      serviceConfig.Type = "oneshot";
      script = ''
        set -e
        ${pkgs.wol}/bin/wol 04:92:26:d8:77:9a -v
      '';
    };

    services.disable-led =
    let
      start = pkgs.writeShellScript "start" ''
        set -e
        echo 0 > /sys/class/leds/led0/brightness
        echo 0 > /sys/class/leds/led1/brightness
      '';

      stop = pkgs.writeShellScript "stop" ''
        set -e
        echo 1 > /sys/class/leds/led0/brightness
        echo 1 > /sys/class/leds/led1/brightness
      '';
    in {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = start;
        ExecStop = stop;
      };
    };
  };

  system.stateVersion = "22.11";
}
