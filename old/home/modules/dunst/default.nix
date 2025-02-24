{ pkgs, config, ... }:
let
  font = config.theme.font;
  color = config.theme.color;
  transparency = "A0";
in
{
  config.home = {
    packages = [ pkgs.dunst ];
    file.".config/dunstrc" = {
      text = ''
        [global]
            monitor = 0
            font = "${font.family} 10"
            allow_markup = yes
            format = "%s\n<span style='italic' color='#${color.fg4}'>%b</span>"
            sort = yes
            indicate_hidden = yes
            alignment = center
            bounce_freq = 0
            show_age_threshold = 60
            word_wrap = yes
            ignore_newline = no
            geometry = "500x5-20+20"
            max_icon_size = 120
            transparency = 1
            idle_threshold = 120
            monitor = 0
            sticky_history = yes
            line_height = 0
            separator_height = 3
            padding = 8
            horizontal_padding = 8
            separator_color = "#${color.bg2}"
            startup_notification = false

        [frame]
            width = 3
            color = "#${color.accent.dark}"

        [urgency_low]
            background = "#${color.bg}${transparency}"
            foreground = "#${color.bright.fg}"
            timeout = 5

        [urgency_normal]
            background = "#${color.bg}${transparency}"
            foreground = "#${color.bright.fg}"
            timeout = 10

        [urgency_critical]
            background = "#${color.bg}${transparency}"
            foreground = "#${color.bright.red}"
            timeout = 20
      '';
      onChange = ''
        if pgrep dunst; then
          echo "Reloading dunst"
          systemctl --user restart dunst.service
        fi
      '';
    };
  };
}
