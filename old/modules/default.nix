{ pkgs, lib, config, custom, ... }:

with lib;

let
  cfg = config.usage;
  keys = (import ./keys);
in {
  imports = [
    ./git-server.nix
    ./graphical.nix
    ./virt-host.nix
    ./webhook-rebuild.nix
  ];

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
      (builtins.readFile ./keys/ca.crt)
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
}
