{ pkgs, lib, config, flake, ... }: {
  imports = [ flake.inputs.lanzaboote.nixosModules.lanzaboote ];

  # Disable systemd bootloader for lanzaboote
  boot.loader.systemd-boot.enable = false;
  # Enable secure boot
  boot.lanzaboote.enable = true;
  boot.lanzaboote.pkiBundle = "/var/lib/sbctl";
  # Add sbctl utility
  environment.systemPackages = [ pkgs.sbctl ];

  environment.persistence."/persist".directories = let
    enabled = config.environment.persistence."/persist".enable;
  in lib.mkIf enabled [
    "/var/lib/sbctl"
  ];
}
