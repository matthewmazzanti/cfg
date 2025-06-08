{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  color = config.theme.color;

  font = config.theme.font;
  fontSize = toString font.size;
  fontString = "${fontSize}pt 'Fira Code'";

  mkFont = x: "c.fonts." + x + " = \"${fontString}\"";
  mkFonts = concatMapStringsSep "\n" mkFont;
in {
  options = {
    theme = mkOption {
      type = types.attrs;
    };
  };

  config.home = {
    # TODO: undo this
    packages = [pkgs.qutebrowser];
    file = {
      ".config/qutebrowser/config.py" = {
        text = ''
          config.load_autoconfig()
          c.content.blocking.method = "both"
          c.content.blocking.enabled = True

          c.qt.args = [
            "ignore-gpu-blocklist",
            "enable-gpu-rasterization",
            "enable-native-gpu-memory-buffers",
            "num-raster-threads=8",
            "enable-zero-copy"
          ]
          c.qt.highdpi = True

          c.tabs.title.alignment = "center"
          c.tabs.title.format = "{current_title}"
          c.tabs.indicator.width = 0
          c.tabs.show = "multiple"
          c.tabs.favicons.show = "always"

          ${mkFonts [
            "completion.category"
            "completion.entry"
            "contextmenu"
            "debug_console"
            "downloads"
            "keyhint"
            "messages.error"
            "messages.info"
            "messages.warning"
            "prompts"
            "statusbar"
            "tabs.selected"
            "tabs.unselected"
          ]}
          c.fonts.hints = "bold ${fontSize}pt ${font.family}"


          c.hints.border = "0px"
          c.content.pdfjs = True

          c.colors.tabs.bar.bg = "#${color.bg}"
          c.colors.tabs.even.bg = "#${color.bg}"
          c.colors.tabs.even.fg = "#${color.fg}"
          c.colors.tabs.odd.bg = "#${color.bg}"
          c.colors.tabs.odd.fg = "#${color.fg}"
          c.colors.tabs.selected.even.bg = "#${color.accent.dark}"
          c.colors.tabs.selected.even.fg = "#${color.bright.fg}"
          c.colors.tabs.selected.odd.bg = "#${color.accent.dark}"
          c.colors.tabs.selected.odd.fg = "#${color.bright.fg}"

          c.colors.hints.bg = "#${color.bright.yellow}"
          c.colors.hints.fg = "#${color.bg}"
          c.colors.hints.match.fg = "#${color.bright.red}"

          c.colors.statusbar.normal.bg = "#${color.bg}"
          c.colors.statusbar.normal.fg = "#${color.bright.fg}"
          c.colors.statusbar.insert.bg = "#${color.accent.dark}"
          c.colors.statusbar.insert.fg = "#${color.bright.fg}"

          c.colors.statusbar.url.fg = "#${color.bright.fg}"
          c.colors.statusbar.url.hover.fg = "#${color.bright.blue}"
          c.colors.statusbar.url.success.http.fg = "#${color.bright.green}"
          c.colors.statusbar.url.success.https.fg = "#${color.bright.green}"

          c.colors.statusbar.command.bg = "#${color.bg}"
          c.colors.statusbar.command.fg = "#${color.bright.fg}"
          c.colors.statusbar.command.private.bg = "#${color.bg}"
          c.colors.statusbar.command.private.fg = "#${color.bright.fg}"

          c.colors.statusbar.caret.bg = "#${color.orange}"
          c.colors.statusbar.caret.fg = "#${color.bg}"
          c.colors.statusbar.caret.selection.bg = "#${color.bright.orange}"
          c.colors.statusbar.caret.selection.fg = "#${color.bg}"

          c.colors.completion.category.bg = "#${color.accent.dark}"
          c.colors.completion.category.fg = "#${color.bright.fg}"
          c.colors.completion.category.border.top = "#${color.accent.dark}"
          c.colors.completion.category.border.bottom = "#${color.accent.dark}"

          c.colors.completion.even.bg = "#${color.bg}"
          c.colors.completion.odd.bg = "#${color.bg}"
          c.colors.completion.fg = "#${color.fg1}"

          c.colors.completion.item.selected.bg = "#${color.bright.blue}"
          c.colors.completion.item.selected.border.bottom = "#${color.bright.blue}"
          c.colors.completion.item.selected.border.top = "#${color.bright.blue}"
          c.colors.completion.item.selected.fg = "#${color.bg}"

          c.colors.completion.match.fg = "#${color.bright.red}"
          c.colors.completion.item.selected.match.fg = "#${color.bright.red}"

          # Message prompts
          c.colors.messages.error.bg = "#${color.red}"
          c.colors.messages.error.border = "#${color.red}"
          c.colors.messages.error.fg = "#${color.bright.fg}"

          c.colors.messages.warning.bg = "#${color.orange}"
          c.colors.messages.warning.border = "#${color.orange}"
          c.colors.messages.warning.fg = "#${color.bright.fg}"

          c.colors.messages.info.bg = "#${color.bg}"
          c.colors.messages.info.border = "#${color.bg}"
          c.colors.messages.info.fg = "#${color.bright.fg}"

          c.colors.webpage.preferred_color_scheme = "dark"

          ${readFile ./config.py}
        '';
        onChange = ''
          if pgrep qutebrowser; then
            echo "Reloading qutebrowser"
            qutebrowser :config-source
          fi
        '';
      };
    };
  };
}
