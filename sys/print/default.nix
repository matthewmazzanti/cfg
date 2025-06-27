{ pkgs, flake, ... }: {
  imports = [
    flake.modules.base
    flake.modules.impermanence
    flake.modules.lanzaboote
    ./hardware.nix
    ./home-automation.nix
  ];

  # Networking
  networking.hostName = "hass";
  networking.hostId = "d015a266"; # TODO: Move with zfs settings
  networking.networkmanager.enable = true;
  environment.persistence."/persist".directories = [
    "/etc/NetworkManager/system-connections"
    "/var/lib/NetworkManager"
  ];

  # ZFS auto-cleanup
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # Packages
  environment.systemPackages = with pkgs; [
    # Installation/debug utils
    e2fsprogs
    gptfdisk
    usbutils
  ];

  # User config
  users.users.mmazzanti = {
    extraGroups = ["networkmanager" "podman" "dialout"];
    packages = [ flake.packages."nvim/nix" ];
  };
}
