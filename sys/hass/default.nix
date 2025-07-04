{ flake, ... }: {
  imports = [
    flake.modules.base
    flake.modules.impermanence
    flake.modules.lanzaboote
    ./hardware.nix
    # ./home-automation.nix
  ];

  # Networking
  networking.hostName = "hass";

  # ZFS auto-cleanup
  networking.hostId = "224d13b2";
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # Packages
  # environment.systemPackages = with pkgs; [];

  # User config
  users.users.mmazzanti = {
    extraGroups = ["networkmanager" "podman" "dialout"];
    packages = [ flake.packages."nvim/nix" ];
  };

  systemd.network = {
    enable = true;
    networks."00-enp1s0" = {
      matchConfig.Name = "enp1s0";
      networkConfig = {
        Address = "172.16.2.10/20";
        Gateway = "172.16.0.1";
        DNS = [ "172.16.0.1" ];
        VLAN = [ "enp1s0.18" ];
      };
    };

    netdevs."05-enp1s0.18" = {
      netdevConfig = {
        Name = "enp1s0.18";
        Kind = "vlan";
      };
      vlanConfig = {
        Id = 18;
      };
    };

    networks."05-enp1s0.18" = {
      matchConfig.Name = "enp1s0.18";
      networkConfig = {
        # Disable networking through this interface for the host
        DHCP = "no";
        IPv6AcceptRA = false;
        LinkLocalAddressing = "no";
      };
    };
  };
}
