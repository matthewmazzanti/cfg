{ pkgs, lib, config, ... }:

with lib;

let
  font = config.theme.font;
  color = config.theme.color;
  dirs = config.home.xdg.dirs;
in {
  options = {
    theme = mkOption {
      type = types.attrs;
    };
  };

  config.home = {
    packages = with pkgs; [ bat ];
    file = {
      "${dirs.config}/bat/config".text = ''
        --theme="gruvbox-dark"
        --style="header,grid,snip"
        --italic-text=always
        --map-syntax h:cpp
        --map-syntax .ignore:.gitignore
      '';
    };
  };
}
