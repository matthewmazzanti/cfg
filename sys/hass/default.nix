{ flake, ... }: {
  imports = [
    flake.modules.base
    flake.modules.impermanence
    flake.modules.lanzaboote
    ./hardware.nix
    ./home-automation.nix
  ];

  # Networking
  networking.hostName = "hass";
  # networking.networkmanager.enable = true;
  # environment.persistence."/persist".directories = [
  #   "/etc/NetworkManager/system-connections"
  #   "/var/lib/NetworkManager"
  # ];

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

  networking.useNetworkd = true;
  systemd.network = {
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
        Id = 2;
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

    netdevs."10-br-int" = {
      netdevConfig = {
        Name = "br-int";
        Kind = "bridge";
      };
    };

    networks."10-br-int" = {
      matchConfig.Name = "br-int";
      networkConfig.Address = "192.168.0.1/24";
    };

    netdevs."20-veth-ha" = {
      netdevConfig = {
        Name = "veth-ha";
        Kind = "veth";
      };
      vethPeerConfig.Name = "veth-ha-c";
    };

    networks."20-veth-ha" = {
      matchConfig.Name = "veth-ha";
      networkConfig.Bridge = "br-int";
    };

    netdevs."20-veth-zwave" = {
      netdevConfig = {
        Name = "veth-zwave";
        Kind = "veth";
      };
      vethPeerConfig.Name = "veth-zwave-c";
    };

    networks."20-veth-zwave" = {
      matchConfig.Name = "veth-zwave";
      networkConfig.Bridge = "br-int";
    };

    netdevs."30-macvlan-ha" = {
      netdevConfig = {
        Name = "macvlan-ha";
        Kind = "macvlan";
      };
      macvlanConfig = {
        Mode = "bridge";
      };
    };

    networks."30-macvlan-ha" = {
      matchConfig.Name = "macvlan-ha";
      networkConfig.ConfigureWithoutCarrier = true;
    };
  };
}
