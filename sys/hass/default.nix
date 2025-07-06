{ config, pkgs, flake, ... }: {
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
  environment.systemPackages = with pkgs; [
    iptables
    nftables
  ];

  environment.persistence."/persist".directories = [ "/var/lib/containers" ];

  # User config
  users.users.mmazzanti = {
    extraGroups = ["networkmanager" "podman" "dialout"];
    packages = [ flake.packages."nvim/nix" ];
  };

  virtualisation.quadlet = {
    networks.ha.networkConfig = {
      driver = "macvlan";
      subnets = [ "172.18.0.0/16" ];
      gateways = [ "172.18.0.1" ];
    };

    pods.ha.podConfig = {
      name = "ha";
      networks = [ "ha:ip=172.18.2.11,mac=02:fd:38:25:58:f9" ];
      dns = [ "172.18.0.1" ];
      uidMaps = [ "0:100000:65536" ];
      gidMaps = [ "0:100000:65536" ];
    };

    /*
    containers = {
      nginx = {
        unitConfig = {
          After = [ "var-lib-nginx.mount" ];
          Requires = [ "var-lib-nginx.mount" ];
        };
        containerConfig = {
          name = "nginx";
          pod = "ha.pod";
          image = "docker.io/library/nginx:alpine-slim@sha256:e4e764cb35f666f44dd4e1da4291a5f73bb8bff2a9464ccecd8a05a2b7226ad5";
          # dropCapabilities = ["ALL"];
          # noNewPrivileges = true;
          # readOnly = true;
          # tmpfses = [ "/var/run" "/tmp" ];
          volumes = [
            "${./nginx.conf}:/etc/nginx/nginx.conf:ro"
            "/var/lib/nginx/ssl:/etc/nginx/ssl:ro"
          ];
          environments.TZ = config.time.timeZone;
        };
      };

      hass = {
        unitConfig = {
          After = [ "var-lib-hass.mount" ];
          Requires = [ "var-lib-hass.mount" ];
        };
        containerConfig = {
          name = "hass";
          pod = "ha.pod";
          image = "ghcr.io/home-assistant/home-assistant:stable@sha256:d80b831e5a7ec80949231d45c4bea9102c60d5e2f02c961d3120e5d48226cbc9";
          # dropCapabilities = ["ALL"];
          addCapabilities = ["FOWNER" "NET_RAW"];
          # noNewPrivileges = true;
          # readOnly = true;
          # tmpfses = [ "/var/run" "/tmp" ];
          volumes = [
            "/etc/localtime:/etc/localtime:ro"
            "/var/lib/hass:/config:rw"
            "${./configuration.yaml}:/config/configuration.yaml:ro"
            "${flake.inputs.slider-entity-row}:/config/www/slider-entity-row:ro"
            "${flake.inputs.pyscript}/custom_components/pyscript:/config/custom_components/pyscript:ro"
          ];
          environments.TZ = config.time.timeZone;
        };
      };

      zwave = {
        unitConfig = {
          After = [ "var-lib-zwave.mount" ];
          Requires = [ "var-lib-zwave.mount" ];
        };
        containerConfig = {
          name = "zwave";
          pod = "ha.pod";
          image = "zwavejs/zwave-js-ui@sha256:52b6ee2c37fa1a3c13a8d8f59b45145b546ec31b5c85d5053e1279fc558c5a1e";
          # dropCapabilities = ["ALL"];
          # addCapabilities = ["FOWNER" "NET_RAW"];
          # noNewPrivileges = true;
          # readOnly = true;
          # tmpfses = [ "/var/run" "/tmp" ];
          devices = [ "/dev/serial/by-id/usb-Silicon_Labs_CP2102N_USB_to_UART_Bridge_Controller_e015830c1ba4eb11a4f62a259da30875-if00-port0:/dev/zwave" ];
          environments.TZ = config.time.timeZone;
        };
      };
    };
    */
  };
}
