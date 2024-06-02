{ pkgs, lib, config,... }:

with lib;

let
  cfg = config.usage;

  keys = (import ./keys);

  # TODO: Remove this, replace with configured neovim
  neovim = pkgs.neovim.override {
    configure = {
      customRC = readFile ./vimrc.vim;
      packages.custom.start = with pkgs.vimPlugins; [ gruvbox vim-nix ];
    };
    viAlias = true;
    vimAlias = true;
    withPython3 = false;
    withRuby = false;
  };
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
      ] ++ [
        neovim
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
      vim.defaultEditor = true;
      zsh.enable = true;
      gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
        pinentryFlavor = if cfg.graphical.enable then "qt" else "curses";
      };
    };

    services = {
      openssh = {
        enable = true;
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
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
