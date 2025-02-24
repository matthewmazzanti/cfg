{ pkgs, lib, config, ...}:
with lib;
with builtins;
let
  xdg = config.home.xdg;

  replacePrefix = prefix: replace: value:
    if hasPrefix prefix value then
      replace + (removePrefix prefix value)
    else
      value;

  toHome = mapAttrs (_: value: replacePrefix "~" "${config.home.homeDirectory}" value);

  # XDG spec has the CACHE, CONFIG, and DATA dirs post-fixed with _HOME, rather
  # than the _DIR for the rest of the directories. Match the directories and
  # add the appropriate post-fix to the generated variable names.
  homeDirs = [ "CACHE" "CONFIG" "DATA" ];
  toEnv = mapAttrs' (name: value:
    let
      name' = toUpper name;
      xdgSuffix = name: if (elem name homeDirs) then "_HOME" else "_DIR";
    in
      nameValuePair ("XDG_" + name' + (xdgSuffix name')) value);

  # Turn the environment variables from an attribute set into a text file of
  # KEY="VALUE", for compatibility with the xdg-user-dirs tool.
  toUserDirs = mapAttrsToList (name: value: "${name}=\"${value}\"");
  toFile = env: concatStringsSep "\n" (toUserDirs env);
in {
  options.home.xdg = {
    enable = mkEnableOption "Enable home xdg dirs";
    dirs = mkOption {
      default = rec {
        # Defaults here should match the XDG user dirs defaults
        cache  = "~/.cache";
        config = "~/.config";
        data   = "~/.local/share";

        download = "~/Downloads";
        publicshare = "~/Public";

        documents = "~/Documents";
        templates = "~/Templates";
        desktop = "~/Desktop";

        music = "~/Music";
        pictures = "~/Pictures";
        videos = "~/Videos";
      };
      type = types.attrsOf types.str;
      apply = toHome;
    };

  };

  config.home = mkIf xdg.enable {
    sessionVariables = toEnv xdg.dirs;
    file."${xdg.dirs.config}/user-dirs.dirs".text = toFile (toEnv xdg.dirs);
  };
}
