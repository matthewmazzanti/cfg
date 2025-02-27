{ pkgs, lib, config, ... }:
with lib;
let
  dirs = config.home.xdg.dirs;
  color = config.theme.color;
  xcfg = {
    dpi = 168;
    autoRepeatDelay = 300;
    autoRepeatInterval = 40;
  };

  xargs
    = optional (xcfg.dpi != null)
      "-dpi ${toString xcfg.dpi}"
    ++ optional (xcfg.autoRepeatDelay != null)
      "-ardelay ${toString xcfg.autoRepeatDelay}"
    ++ optional (xcfg.autoRepeatInterval != null)
      "-arinterval ${toString xcfg.autoRepeatInterval}";

  xargs-string = builtins.concatStringsSep " " xargs;

  x = pkgs.writeShellScriptBin "x" ''
    ${pkgs.xorg.xinit}/bin/startx ${bspwm-script} -- ${xargs-string}
  '';

  mkPath = strings.makeSearchPathOutput "out" "bin";

  kitty-si = pkgs.callPackage ../../scripts/kitty-si {};

  bspwm-config = pkgs.writeShellScript "bspwm-config" ''
    bspc monitor DisplayPort-0 -d f g d s a v b c x z
    bspc monitor DisplayPort-1 -d j h k l ";" m n "," "." "/"
    bspc monitor HDMI-A-0 -d r t e w q u y i o p

    bspc config border_width 4
    bspc config window_gap 40
    bspc config normal_border_color "#${color.bg}"
    bspc config active_border_color "#${color.bg}"
    bspc config focused_border_color "#${color.accent.dark}"

    bspc config ignore_ewmh_focus true
    bspc config focus_follows_pointer true
    bspc config pointer_follows_focus true

    bspc rule -a qutebrowser desktop=j
    bspc rule -a Spotify desktop=h
    bspc rule -a Steam desktop=s
    bspc rule -a dota2 desktop=s
    bspc rule -a 'Microsoft Teams - Preview' desktop=l
    bspc rule -a Firefox desktop=k
    bspc rule -a Zathura desktop=k state=tiled
  '';

  bspwm-script = pkgs.writeShellScript "my-bspwm" ''
    xrandr \
      --output DisplayPort-0 --primary --pos 0x2160 \
      --output DisplayPort-1 --pos 3840x2160 \
      --output HDMI-A-0 --pos 1920x0
    export XCURSOR_THEME=Adwaita
    export XCURSOR_SIZE=48
    xsetroot -cursor_name left_ptr
    systemctl --user import-environment PATH DISPLAY XCURSOR_THEME XCURSOR_SIZE
    systemctl --user start bspwm.target
    ${pkgs.bspwm}/bin/bspwm -c ${bspwm-config}
    systemctl --user stop bspwm.target
  '';

  # Stolen with love:
  # https://www.reddit.com/r/bspwm/comments/fkgc94/monocle_true_transparency_hiding_not_focused_node/
  monocle-hide = pkgs.writeShellScriptBin "monocle-hide" ''
      set -e
      PATH="${mkPath (with pkgs; [bspwm xorg.xprop findutils])}"
      HINT="_PICOM_MONOCLE"
      ${builtins.readFile ./monocle-hide.sh}
  '';

  node-transparency = pkgs.writeShellScriptBin "node-transparency" ''
      set -e
      PATH="${mkPath (with pkgs; [bspwm xorg.xprop findutils jq.bin])}"
      HINT="_PICOM_MONOCLE"
      ${builtins.readFile ./node-transparency.sh}
  '';

  # hass-notify = (pkgs.callPackage ~/src/home/room/hass-notify {});
in {
  config = {
    home = {
      packages = with pkgs; [
        # My scripts/renames
        x
        kitty-si

        # External scripts, mostly for cli access to documentation
        bspwm
        sxhkd
        polybar
        xorg.xdpyinfo
        xorg.xev
        adwaita-icon-theme
        unclutter-xfixes
        picom
        hsetroot
        rofi
        jq
      ];

      file = {
        ".imwheelrc" = {
          text = ''
            "^qutebrowser|spotify|zathura$"
            None, Up, Button4, 3
            None, Down, Button5, 3
          '';
          onChange = "systemctl --user restart imwheel.service";
        };

        "${dirs.config}/sxhkd/sxhkdrc" = {
          text = ''
            super + o
                ${pkgs.rofi}/bin/rofi -show run

            super + g
                ${pkgs.rofi}/bin/rofi -show window

            super + v
                ${pkgs.rofi}/bin/rofi -show file-browser

            super + shift + Return
                ${pkgs.kitty}/bin/kitty

            super + Return
                ${kitty-si}/bin/kitty-si

            ${builtins.readFile ./sxhkdrc}
          '';
          onChange = "systemctl --user reload sxhkd.service";
        };
      };
    };

    qt.platformTheme = "gnome";

    myServices.redshift = {
      enable = true;
      latitude = "39.1833333";
      longitude = "-77.266667";
      provider = "manual";
      temperature.night = 3500;
      extraOptions = [ "-r" "-m randr" ];
      systemdTarget = "bspwm.target";
    };

    systemd.user = {
      targets = {
        bspwm.Unit.Description = "bspwm services";
      };

      services = {
        sxhkd = {
          Unit = {
            Description = "simple X hotkey daemon";
            Documentation = "man:sxhkd(1)";
            PartOf = [ "bspwm.target" ];
          };

          Service = {
            ExecStart = "${pkgs.sxhkd}/bin/sxhkd -c ${dirs.config}/sxhkd/sxhkdrc";
            ExecReload = "${pkgs.utillinux}/bin/kill -SIGUSR1 $MAINPID";
            RestartSec = 3;
            Restart = "always";
          };

          Install.WantedBy = [ "bspwm.target" ];
        };

        picom = {
          Unit = {
            Description = "xorg compositing service";
            Documentation = "man:picom(1)";
            PartOf = [ "bspwm.target" ];
          };

          Service = {
            ExecStart = "${pkgs.picom-next}/bin/picom --config ${./picom.conf}";
            RestartSec = 3;
            Restart = "always";
          };

          Install.WantedBy = [ "bspwm.target" ];
        };

        monocle-hide = {
          Unit = {
            Description = "Adjust props for monocle mode";
            PartOf = [ "bspwm.target" ];
          };

          Service = {
            ExecStart = "${monocle-hide}/bin/monocle-hide";
            RestartSec = 3;
            Restart = "always";
          };

          Install.WantedBy = [ "bspwm.target" ];
        };

        node-transparency = {
          Unit = {
            Description = "Update props on focus change";
            PartOf = [ "bspwm.target" ];
          };

          Service = {
            ExecStart = "${node-transparency}/bin/node-transparency";
            RestartSec = 3;
            Restart = "always";
          };

          Install.WantedBy = [ "bspwm.target" ];
        };

        numlock = {
          Unit = {
            Description = "xorg numlock";
            PartOf = [ "bspwm.target" ];
          };

          Service = {
            RemainAfterExit = "true";
            ExecStart = "${pkgs.numlockx}/bin/numlockx on";
            ExecStop = "${pkgs.numlockx}/bin/numlockx off";
          };

          Install.WantedBy = [ "bspwm.target" ];
        };

        background = {
          Unit = {
            Description = "xorg background";
            PartOf = [ "bspwm.target" ];
          };

          Service = {
            RemainAfterExit = "true";
            ExecStart = "${pkgs.hsetroot}/bin/hsetroot -fill /home/mmazzanti/media/img/backgrounds/joey-kyber-sFLVTqNzG2I-unsplash.jpg";
          };

          Install.WantedBy = [ "bspwm.target" ];
        };

        unclutter = {
          Unit = {
            Description = "unclutter cursor";
            PartOf = [ "bspwm.target" ];
          };

          Service = {
            RemainAfterExit = "true";
            ExecStart = "${pkgs.unclutter-xfixes}/bin/unclutter";
          };

          Install.WantedBy = [ "bspwm.target" ];
        };
      };
    };
  };
}
