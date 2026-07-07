{
  lib,
  callPackage,
  writeText,
  system,
  extraConfig ? {},
}:

let
  isDarwin = lib.hasSuffix "darwin" system;
  inherit (callPackage ./format.nix {}) format formatPalette formatKeybinds quote;
  resizeAmount = if isDarwin then "10" else "20";

  base = {
    confirm-close-surface = "false";
    window-padding-x = "5";
    window-padding-y = "5";
    window-inherit-working-directory = "true";
    bell-features = "no-title";

    font-family = quote "Fira Code";
    adjust-cell-height = "-2";
    adjust-cell-width = "-1";
    adjust-cursor-thickness = "2";

    shell-integration = "zsh";
    shell-integration-features = "no-cursor";

    palette = formatPalette {
      black = "#282828";   bright-black = "#928374";
      red = "#cc241d";     bright-red = "#fb4934";
      green = "#98971a";   bright-green = "#b8bb26";
      yellow = "#d79921";  bright-yellow = "#fabd2f";
      blue = "#458588";    bright-blue = "#83a598";
      magenta = "#b16286"; bright-magenta = "#d3869b";
      cyan = "#689d6a";    bright-cyan = "#8ec07c";
      white = "#a89984";   bright-white = "#ebdbb2";
    };

    background = "#282828";
    foreground = "#ebdbb2";
    cursor-color = "#ebdbb2";
    cursor-text = "#282828";
    selection-background = "#504945";
    selection-foreground = "#ebdbb2";
    unfocused-split-opacity = ".8";

    keybind = formatKeybinds {
      "cmd+h" = "goto_split:left";
      "cmd+j" = "goto_split:down";
      "cmd+k" = "goto_split:up";
      "cmd+l" = "goto_split:right";
      "cmd+enter" = "new_split:right";
      "cmd+shift+enter" = "new_split:down";
      "cmd+shift+h" = "resize_split:left,${resizeAmount}";
      "cmd+shift+j" = "resize_split:down,${resizeAmount}";
      "cmd+shift+k" = "resize_split:up,${resizeAmount}";
      "cmd+shift+l" = "resize_split:right,${resizeAmount}";
    };
  };

  platformConfig =
    if isDarwin
    then {
      font-size = "14";
      font-variation = "wght=450";
      adjust-underline-thickness = "2";
      macos-titlebar-style = "tabs";
      split-divider-color = "#504945";
      unfocused-split-fill = "#444444";
    }
    else {
      font-size = "11";
      font-variation = "wght=400";
      font-variation-bold = "wght=600";
      split-divider-color = "#a89984";
      unfocused-split-fill = "#504945";
      gtk-titlebar-style = "tabs";
      # Force client-side decorations. Under "auto", KDE/KWin adds a
      # server-side titlebar on top of ghostty's own libadwaita headerbar
      # (the tab bar) -> two titlebars. "client" is native on GNOME (Mutter
      # is CSD-only, so auto already picks it) and fixes KDE.
      window-decoration = "client";
    };

  config = base // platformConfig // extraConfig;
in
  writeText "ghostty-config" (format config)
