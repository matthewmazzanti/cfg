{ pkgs, lib, config, neovim-flake, ... }:

with lib;
let
  dirs = config.home.xdg.dirs;
  home-pkgs = import ../pkgs { pkgs = pkgs; };

  neovim = neovim-flake.default.override {
    imports = [ neovim-flake.profiles.mmazzanti ];
    vimAlias = true;
  };
in {
  imports = [
    ./sets

    ./kitty
    ./qutebrowser
    ./bspwm
    ./redshift

    ./bat
    ./zsh
    # ./neovim
    ./xdg
    ./less
    ./dunst
    ./rofi
    ./spotify
    # ./mutt
  ];

  config = {
    programs = {
      git = {
        enable = true;
        userName  = "Matthew Mazzanti";
        userEmail = "matthew.mazzanti@gmail.com";
        extraConfig = {
          init.defaultBranch = "dev";
          core.editor = "nvim";
          pull = {
            ff = "only";
            rebase = "false";
          };
          safe = {
            directory = "/etc/nixos";
          };
        };
      };

      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
    };

    theme = {
      font = {
        size = 10;
        family = "FiraCode";
        monospace = "FiraCode-Regular";
        bold = "FiraCode-Bold";
        italic = "FantasqueSansMono-Italic";
        bold-italic = "FiraCode-Regular";
      };
      color = (import ../colors/gruvbox.nix) "dark" "hard";
    };

    fonts.fontconfig.enable = true;

    xdg = {
      configFile."mimeapps.list".force = true;
      mimeApps = {
        enable = true;
        defaultApplications = {
          "text/html" = "org.qutebrowser.qutebrowser.desktop";
          "x-scheme-handler/https" = "org.qutebrowser.qutebrowser.desktop";
          "x-scheme-handler/http" = "org.qutebrowser.qutebrowser.desktop";
          "x-scheme-handler/about" = "org.qutebrowser.qutebrowser.desktop";
          "x-scheme-handler/unknown" = "org.qutebrowser.qutebrowser.desktop";
          # "x-scheme-handler/zommtg" = "zoom.desktop";
          "application/pdf" = "org.pwmt.zathura.desktop";
        };
      };
    };

    home = {
      xdg = {
        enable = true;
        dirs = rec {
          cache  = "~/.cache";
          config = "~/.config";
          data   = "~/.local/share";

          templates = "${data}/templates";
          desktop = "${data}/desktop";
          history = "${data}/history";

          download = "~/dld";
          publicshare = "~/net";
          documents = "~/doc";
          code = "~/src";

          media = "~/media";
          music = "${media}/music";
          pictures = "${media}/img";
          videos = "${media}/vid";
        };
      };

      packages = with pkgs; [
        # Nixos stuff
        nix-prefetch-git
        nix-index

        # Fonts
        # noto-fonts-emoji
        home-pkgs.fira-code
        merriweather
        montserrat
        fantasque-sans-mono
        etBook

        neovim
        steam
        _1password-gui
      ];

      sessionVariables = {
        "EDITOR" = "nvim";
        "QT_SCALE_FACTOR" = "2";
        "GDK_SCALE" = "2";
        "GDK_DPI_SCALE" = "0.5";

        "GEM_HOME" = "${dirs.data}/gem";
        "GOPATH" = "${dirs.data}/go";
        "PASSWORD_STORE_DIR" = "${dirs.data}/password-store";
        "PLATFORMIO_CORE_DIR" = "${dirs.data}/platformio";

        "CARGO_HOME" = "${dirs.cache}/cargo";
        "GEM_SPEC_CACHE" = "${dirs.cache}/gem";

        "NPM_CONFIG_USERCONFIG" = "${dirs.config}/npm/npmrc";
        "HTTPIE_CONFIG_DIR" = "${dirs.config}/httpie";
        "PSQL_HISTORY" = "${dirs.history}/psql";
        "MYSQL_HISTFILE" = "${dirs.history}/mysql";
        "NODE_REPL_HISTORY" = "${dirs.history}/node";
      };

      file = {
        "${dirs.config}/npm/npmrc".source = ./config/npmrc;
        ".haskeline".text = ''
          editMode: Vi
        '';
      };

    };

    systemd.user = {
      startServices = true;
      sessionVariables = config.home.sessionVariables;

      /*
      services = {
        imapnotify = {
          Unit = {
            Description = "IMAP notification daemon";
            PartOf = [ "default.target" ];
          };

          Service = {
            Environment="PATH=${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.isync}/bin";
            ExecStart = "${pkgs.goimapnotify}/bin/goimapnotify -conf ${dirs.config}/imapnotify.conf";
            RestartSec = 3;
            Restart = "always";
          };

          Install.WantedBy = [ "default.target" ];
        };
      };
      */
    };
  };
}
