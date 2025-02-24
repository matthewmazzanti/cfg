{ buildGoPackage, pkgs }:

buildGoPackage rec {
  pname = "short-pwd";
  version = "0.0.2";
  goPackagePath = "github.com/matthewmazzanti/short-pwd";
  src = ./.;
  meta = {
    description = "A small script providing path display with shortening";
  };
}
