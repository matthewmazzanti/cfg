{ pkgs, lib, config, custom, ... }: 
with lib;
let
  keys = (import ../../old/modules/keys);
in {
  imports = [ ./hardware.nix ];

  boot.supportedFilesystems = [ "zfs" ];
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
  boot.tmp.cleanOnBoot = true;
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 10;
    efi.canTouchEfiVariables = true;
  };

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Console visual things
  console = {
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
    keyMap = "us";
  };
  services.getty = {
    greetingLine = "${config.networking.hostName}";
    helpLine = mkForce "";
  };

  # Enable and set zsh as default
  programs.zsh.enable = true;
  # Not sure what this is for
  environment.pathsToLink = [ "/share/zsh" ];
  users.defaultUserShell = pkgs.zsh;

  # Set vi mode in global inputrc
  environment.etc = {
    "inputrc".text = ''
      set editing-mode vi
      set keymap vi
    '';
  };

  # Hardware config
  services.udev = {
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

  # === Graphics Settings ===
  hardware.graphics = {
    # Enables gpu accelerated graphics
    enable = true;
    # Not sure what this is for
    extraPackages = [ pkgs.libva ];
  };
  # xserver settings - these are overriden in custom BS happening in home
  # manager
  services.xserver = {
    enable = true;
    dpi = 168;
    displayManager.startx.enable = true;
    autoRepeatDelay = 300;
    autoRepeatInterval = 40;
    enableCtrlAltBackspace = true;
    videoDrivers = ["amdgpu"];
  };

  # === AUDIO SETTINGS ===
  # 24.09 made pipewire the default - unset for now
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

  networking = {
    hostId = "f43d79c6";
    hostName = "lambda";
  };

  # Enable wake on lan
  networking.interfaces.enp5s0.wakeOnLan.enable = true;

  users.users.mmazzanti.extraGroups = [
    "wheel"
    "usb"
    "dialout"
    "input"
    "video"
    "audio"
  ];
  users.users.mmazzanti.isNormalUser = true;


  # gnupg - TODO: Remove
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-qt;
  };

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  users.users.mmazzanti.openssh.authorizedKeys.keys = with keys.mmazzanti; [
    lambda
    iota
    beta
  ];

  # PKI - trust ca root.
  # TODO: Make new cert chain
  security.pki.certificates = [
    (builtins.readFile ../../old/modules/keys/ca.crt)
  ];


  # Gaming things
  nixpkgs.config.allowUnfree = true;
  programs.steam.enable = true;
  services.udev.packages = [ pkgs.dolphin-emu ];

  # Not sure what this is for
  programs.dconf.enable = true;
  services.dbus.enable = true;


  # === PACKAGES ===
  environment.systemPackages = with pkgs; [
    # Debugging utilities
    pciutils
    usbutils
    radeontop
    radeon-profile
    ddcutil

    # Basic console utils
    wget
    curl
    tree
    git

    # Not sure what this is for
    gnutls
    # gnupg
    gnupg
    zsh
    tmux
    kitty.terminfo
    ethtool
    custom."nvim/root"
  ];

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

  system.stateVersion = "20.09";
}
