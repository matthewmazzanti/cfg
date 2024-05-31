{ pkgs,  config, ... }:

let
  dirs = config.home.xdg.dirs;
  lesskey = "${dirs.config}/less/lesskey";

  lesskeyBin = pkgs.runCommand "lesskey-bin" {} ''
    echo $out
    ${pkgs.less}/bin/lesskey -o $out -- ${./lesskey}
  '';
in {
  config.home = {
    sessionVariables = {
      "LESSKEY" = "${lesskey}";
      "LESSHISTFILE" = "${dirs.history}/less";
    };
    file."${lesskey}".source = lesskeyBin;
  };
}
