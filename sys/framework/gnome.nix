{ lib, ... }:
let
  inherit (lib.hm.gvariant) mkUint32 mkTuple;
in {
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      sources = [ (mkTuple [ "xkb" "us" ]) ];
      xkb-options = [ "caps:escape" ];
    };
    "org/gnome/desktop/peripherals/keyboard" = {
      delay = mkUint32 300;
      repeat-interval = mkUint32 16;
    };
    "org/gnome/desktop/peripherals/mouse" = {
      accel-profile = "flat";
      speed = 0.0;
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      tap-to-click = true;
      natural-scroll = false;
      two-finger-scrolling-enabled = true;
      disable-while-typing = true;
    };
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      show-battery-percentage = true;
    };
    "org/gnome/mutter" = {
      experimental-features = [ "scale-monitor-framebuffer" ];
      overlay-key = "";
    };
    "org/gnome/desktop/wm/keybindings".minimize = [];   # disables Super+H — drop this line to restore it
    "org/gnome/shell/keybindings".toggle-overview = [ "<Super>o" ];
    "org/gnome/settings-daemon/plugins/media-keys".screensaver = [];
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
      sleep-inactive-battery-type = "suspend";
      ambient-enabled = false;   # disable automatic (ambient light sensor) brightness
    };
    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-schedule-automatic = true;
      night-light-temperature = mkUint32 3350;
    };
    "org/gnome/Console" = {
      custom-font = "Fira Code 12";
      use-system-font = false;
      audible-bell = false;
      visual-bell = false;
    };
    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "list-view";
      search-filter-time-type = "last_modified";
    };
  };
}
