{ pkgs, ... }: {
  imports = [
    ./hardware.nix
    # modules/default.nix
    ({ pkgs, lib, config, custom, ... }:

    with lib;

    let
      cfg = config.usage;
      keys = (import ../../old/modules/keys);
    in {
      config = {
        time.timeZone = "America/New_York";
        i18n.defaultLocale = "en_US.UTF-8";

        console = {
          font = if cfg.graphical.hidpi
            then "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz"
            else "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";
          keyMap = "us";
        };

        environment = {
          systemPackages = with pkgs; [
            gnutls
            pciutils
            usbutils

            wget
            curl
            tree
            git

            gnupg
            zsh
            tmux
            kitty.terminfo
            ethtool
            custom."nvim/root"
          ];

          pathsToLink = [ "/share/zsh" ];

          etc = {
            "inputrc".text = ''
              set editing-mode vi
              set keymap vi
            '';
          };
        };

        programs = {
          zsh.enable = true;
          gnupg.agent = {
            enable = true;
            enableSSHSupport = true;
            pinentryPackage = if cfg.graphical.enable then pkgs.pinentry-qt else pinentry-curses;
          };
        };

        services = {
          openssh = {
            enable = true;
            settings = {
              PermitRootLogin = "no";
              PasswordAuthentication = false;
              KbdInteractiveAuthentication = false;
            };
          };

          getty = {
            greetingLine = "${config.networking.hostName}";
            helpLine = mkForce "";
          };
        };

        security.pki.certificates = [
          (builtins.readFile ../../old/modules/keys/ca.crt)
        ];

        users = {
          defaultUserShell = pkgs.zsh;
          users.mmazzanti = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = with keys.mmazzanti; [
              lambda
              iota
              beta
            ];
          };
        };
      };
    })
    # graphical.nix
    ({ pkgs, lib, config,... }:

    with lib;

    let
      cfg = config.usage.graphical;
    in {
      options.usage.graphical = {
        enable = mkEnableOption "graphical";

        hidpi = mkOption {
          default = false;
          type = types.bool;
          description = "Whether the screen is high dpi";
        };
      };

      config = mkIf cfg.enable {
        users.users.mmazzanti.extraGroups = [ "video" "audio" ];

        services = {
          xserver = {
            enable = true;
            displayManager.startx.enable = true;
            autoRepeatDelay = 300;
            autoRepeatInterval = 40;
            enableCtrlAltBackspace = true;
            videoDrivers = ["amdgpu"];
          };

          dbus.enable = true;

        };

        programs.dconf.enable = true;

        services.pipewire.enable = false;
        services.pulseaudio = {
          enable = true;
          support32Bit = true;
          daemon.config = {
            resample-method = "speex-float-10";
            avoid-resampling = "true";
            default-sample-rate = "48000";
          };
        };

        hardware.graphics = {
          enable = true;
          extraPackages = [ pkgs.libva ];
        };
      };
    })
  ];

  nixpkgs.config.allowUnfree = true;
  usage = {
    graphical = {
      enable = true;
      hidpi = true;
    };
  };

  services = {
    xserver.dpi = 168;
    udev = {
      packages = [ pkgs.dolphin-emu ];
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

    home.file = {
      ".gnupg/sshcontrol".text = ''
        62BD6A1B82D27AA64641BB11E282649654EFD6BB
      '';
    };
  };

  programs.steam.enable = true;

  system.stateVersion = "20.09";
}
