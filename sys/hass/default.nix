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
        disableDns = true;
        subnets = [ "192.168.100.0/24" ];
      };

      ha-macvlan.networkConfig = {
        driver = "macvlan";
        options = "parent=enp1s0.18";
        subnets = [ "172.18.0.0/20" ];
        gateways = [ "172.18.0.1" ];
      };
    };

    containers = {
      nginx.containerConfig = {
        name = "nginx";
        uidMaps = ["0:200000:65536"];
        gidMaps = ["0:200000:65536"];
        networks = [ "ha-internal:ip=192.168.100.2" ];
        dns = [ "172.18.0.1" ];
        environments.TZ = config.time.timeZone;
        # TODO: Remove/update following
        addCapabilities = [ "NET_RAW" ];
        image = "docker.io/nicolaka/netshoot:latest";
        entrypoint = builtins.toJSON ["sleep" "infinity"];
      };

      hass.containerConfig = {
        name = "hass";
        uidMaps = ["0:300000:65536"];
        gidMaps = ["0:300000:65536"];
        dropCapabilities = ["ALL"];
        addCapabilities = ["CHOWN" "FOWNER"];
        volumes = [
          "/etc/localtime:/etc/localtime:ro"
          "/persist/containers/hass/config:/config:rw"
          "${./hass-config/configuration.yaml}:/config/configuration.yaml:ro"
          "${flake.inputs.slider-entity-row}:/config/www/slider-entity-row:ro"
          "${flake.inputs.pyscript}/custom_components/pyscript:/config/custom_components/pyscript:ro"
        ];
        networks = [
          "ha-macvlan:ip=172.18.2.10,mac=02:11:22:33:44:55"
          "ha-internal:ip=192.168.100.3"
        ];
        dns = [ "172.18.0.1" ];
        environments.TZ = config.time.timeZone;
        # TODO: Remove/update following
        # addCapabilities = [ "NET_RAW" ];
        image = "ghcr.io/home-assistant/home-assistant@sha256:e207929bdf5dc95db43c618b877364e99f7ad506ec5440aeef80d5c9c1cae668";
        # entrypoint = builtins.toJSON ["sleep" "infinity"];
      };

      zwave.containerConfig = {
        name = "zwave";
        uidMaps = ["0:400000:65536"];
        gidMaps = ["0:400000:65536"];
        devices = [ "/dev/serial/by-id/usb-Silicon_Labs_CP2102N_USB_to_UART_Bridge_Controller_e015830c1ba4eb11a4f62a259da30875-if00-port0:/dev/zwave" ];
        environments.TZ = config.time.timeZone;
        networks = [ "ha-internal:ip=192.168.100.4" ];
        # TODO: Remove/update following
        addCapabilities = [ "NET_RAW" ];
        image = "docker.io/nicolaka/netshoot:latest";
        entrypoint = builtins.toJSON ["sleep" "infinity"];
      };
    };
  };
}
