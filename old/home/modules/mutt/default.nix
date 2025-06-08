{
  pkgs,
  config,
  ...
}: let
  dirs = config.home.xdg.dirs;
in {
  config.home = {
    packages = with pkgs; [mutt];
    file = {
      "${dirs.config}/mutt/muttrc".text = ''
        ${builtins.readFile ./muttrc}
      '';
    };
  };
}
