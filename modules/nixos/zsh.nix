{ pkgs, flake, lib, ... }: let
  zshDevExe = lib.getExe flake.packages."zsh/dev";
in {
  # Enable zsh
  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;
  environment.shells = [ zshDevExe ];
  users.users.mmazzanti = {
    shell = zshDevExe;
    packages = [ flake.packages."zsh/dev" ];
  };
}
