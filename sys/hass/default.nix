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

      ha-macvlan = {
        unitConfig = {
          after = [ "sys-devices-virtual-net-enp1s0.18.device" ];
          requires = [ "sys-devices-virtual-net-enp1s0.18.device" ];
        };
        networkConfig = {
          driver = "macvlan";
          options = "parent=enp1s0.18";
          subnets = [ "172.18.0.0/20" ];
          gateways = [ "172.18.0.1" ];
        };
      };
    };

    containers = {
      nginx = {
        unitConfig = {
          after = [ "var-lib-nginx.mount" ];
          requires = [ "var-lib-nginx.mount" ];
        };
        containerConfig = {
          name = "nginx";
          image = "docker.io/library/nginx:alpine-slim@sha256:e80262314d449f100c1c010f76b50bcac17dc48be6cb177382ae63208c7c1461";
          uidMaps = ["0:200000:65536"];
          gidMaps = ["0:200000:65536"];
          dropCapabilities = ["ALL"];
          readOnly = true;
          tmpfses = [ "/var/run" "/tmp" ];
          volumes = [
            "${./nginx.conf}:/etc/nginx/nginx.conf:ro"
            "/var/lib/nginx/ssl:/etc/nginx/ssl:ro"
          ];
          networks = [ "ha-internal:ip=192.168.100.2" ];
          publishPorts = ["172.16.2.10:80:8080" "172.16.2.10:443:8443"];
          environments.TZ = config.time.timeZone;
        };
      };

      hass = {
        unitConfig = {
          after = [ "var-lib-hass.mount" ];
          requires = [ "var-lib-hass.mount" ];
        };
        containerConfig = {
          name = "hass";
          image = "ghcr.io/home-assistant/home-assistant:stable@sha256:d80b831e5a7ec80949231d45c4bea9102c60d5e2f02c961d3120e5d48226cbc9";
          uidMaps = ["0:300000:65536"];
          gidMaps = ["0:300000:65536"];
          dropCapabilities = ["ALL"];
          addCapabilities = ["FOWNER" "NET_RAW"];
          readOnly = true;
          tmpfses = [ "/var/run" "/tmp" ];
          volumes = [
            "/etc/localtime:/etc/localtime:ro"
            "/var/lib/hass:/config:rw"
            "${./configuration.yaml}:/config/configuration.yaml:ro"
            "${flake.inputs.slider-entity-row}:/config/www/slider-entity-row:ro"
            "${flake.inputs.pyscript}/custom_components/pyscript:/config/custom_components/pyscript:ro"
          ];
          networks = [
            "ha-macvlan:ip=172.18.2.10,mac=02:fd:38:25:58:f9"
            "ha-internal:ip=192.168.100.3"
          ];
          dns = [ "172.18.0.1" ];
          environments.TZ = config.time.timeZone;
        };
      };

      zwave = {
        unitConfig = {
          after = [ "var-lib-zwave.mount" ];
          requires = [ "var-lib-zwave.mount" ];
        };
        containerConfig = {
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
  };
}
