{ config, lib, ... }:

with lib;

let
  cfg = config.usage.virt;
in {
  options.usage.virt.host = mkEnableOption "virtualisation host machine";

  config = mkIf cfg.host {
    virtualisation = {
      docker = {
        enable = true;
        storageDriver = "zfs";
      };
      libvirtd.enable = true;
    };
    users.users.mmazzanti.extraGroups = [ "docker" "libvirtd" ];
  };
}
