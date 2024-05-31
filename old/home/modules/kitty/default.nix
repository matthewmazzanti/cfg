{ pkgs, lib, config, ... }:
with lib;
let
  font = config.theme.font;
  color = config.theme.color;
in
{
  options = {
    theme = mkOption {
      type = types.attrs;
    };
  };

  config.home = {
    packages = [ pkgs.kitty ];
    file.".config/kitty/kitty.conf" = {
      text = ''
        background #${color.bg}
        foreground #${color.bright.fg}

        # normal
        color0 #${color.bg}
        color1 #${color.red}
        color2 #${color.green}
        color3 #${color.yellow}
        color4 #${color.blue}
        color5 #${color.purple}
        color6 #${color.cyan}
        color7 #${color.fg}

        # bright
        color8 #${color.bright.bg}
        color9 #${color.bright.red}
        color10 #${color.bright.green}
        color11 #${color.bright.yellow}
        color12 #${color.bright.blue}
        color13 #${color.bright.purple}
        color14 #${color.bright.cyan}
        color15 #${color.bright.fg}

        # extended
        color16 #${color.orange}
        color17 #${color.bright.orange}
        color18 #${color.bg0}
        color19 #${color.bg1}
        color20 #${color.bg2}
        color21 #${color.bg3}
        color22 #${color.bg4}
        color23 #${color.gray}
        color24 #${color.fg4}
        color25 #${color.fg3}
        color26 #${color.fg2}
        color27 #${color.fg1}
        color28 #${color.fg0}

        font_family ${font.monospace}
        bold_font ${font.bold}
        font_size ${toString (font.size * 2)}
        window_padding_width ${toString (font.size * 2)}
        allow_remote_control yes
        enable_audio_bell no

        open_url_with qutebrowser
        open_url_modifiers ctrl

        map ctrl+shift+f kitten hints --ascending --alphabet fjdkslaghvmru

        background_opacity 0.85
        dynamic_background_opacity yes
        confirm_os_window_close 0
      '';
      onChange = ''
        echo "Reloading kitty config"
        if [ -S "$XDG_RUNTIME_DIR/kitty" ]; then
          kitty @ --to "unix:$XDG_RUNTIME_DIR/kitty" \
            set-colors --all \
            --configured ~/.config/kitty/kitty.conf
        fi
      '';
    };
  };
}
