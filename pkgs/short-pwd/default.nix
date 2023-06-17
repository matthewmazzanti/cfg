{ buildGoPackage, ... }:

buildGoPackage {
  pname = "short-pwd";
  version = "0.0.3";
  goPackagePath = "github.com/matthewmazzanti/term-flake/short-pwd";
  src = ./.;
  meta = {
    description = "A small script providing path display with shortening";
  };
}
