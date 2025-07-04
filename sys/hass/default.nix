{ config, flake, ... }: {
  imports = [
    flake.modules.base
    flake.modules.impermanence
    flake.modules.lanzaboote
    flake.modules.quadlet
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

  networking.useDHCP = false;
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
      # Don't bring the link up
      linkConfig.Unmanaged = true;
    };
  };

  virtualisation.quadlet = {
    networks = {
      ha-internal.networkConfig = {
        driver = "bridge";
        internal = true;
        subnets = [ "192.168.100.0/24" ];
      };

      ha-macvlan.networkConfig = {
        driver = "macvlan";
        options = "parent=enp1s0.18";
        subnets = [ "172.18.0.0/20" ];
        ipRanges = [ "172.18.2.10/32" ];
      };
    };

    containers = {
      hass.containerConfig = {
        name = "hass";
        networks = [
          "ha-internal:alias=hass"
          "ha-macvlan:mac=02:11:22:33:44:55"
        ];
        addCapabilities = [
          "NET_RAW"
        ];
        image = "docker.io/nicolaka/netshoot:latest";
      };
    };
  };
}
