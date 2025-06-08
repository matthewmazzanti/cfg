{
  callPackage,
  direnv,
  nix-direnv,
}: let
  direnvrc = ''
    source ${nix-direnv}/share/nix-direnv/direnvrc
  '';
in
  callPackage ./wrapper.nix {
    inherit direnv direnvrc;
  }
