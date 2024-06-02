{ pkgs, config, ... }:
let
  dirs = config.home.xdg.dirs;

  spotifyd = (pkgs.spotifyd.override (attrs: {
    withMpris = true;
  }));
in
{
  config = {
    home.packages = with pkgs; [
      spotifyd
      playerctl
      ncspot
    ];

    /*
    systemd.user.services = {
      spotifyd = {
        Unit = {
          Description = "spotifyd";
          PartOf = [ "default.target" ];
        };

        Service = {
          ExecStart = "${spotifyd}/bin/spotifyd --no-daemon --config-path ${dirs.config}/spotifyd";
          RestartSec = 3;
          Restart = "always";
        };

        Install.WantedBy = [ "default.target" ];
      };
    };
    */
  };
}
