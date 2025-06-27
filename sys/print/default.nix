{ flake, ... }: {
  imports = [
    flake.modules.base
    flake.modules.impermanence
    flake.modules.lanzaboote
    ./hardware.nix
  ];

  # Networking
  networking.hostName = "hass";

  # NetworkManager
  networking.networkmanager.enable = true;
  environment.persistence."/persist".directories = [
    "/etc/NetworkManager/system-connections"
    "/var/lib/NetworkManager"
  ];

  # ZFS
  networking.hostId = "d015a266";
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # Packages
  # environment.systemPackages = with pkgs; [ ];

  # User config
  users.users.mmazzanti = {
    extraGroups = ["networkmanager" "podman" "dialout"];
    packages = [ flake.packages."nvim/nix" ];
  };
}
