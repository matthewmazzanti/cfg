{ config, flake, ... }: {
  environment.persistence."/persist".directories = [ "/var/lib/containers" ];

  virtualisation.quadlet = {
    networks.ha.networkConfig = {
      driver = "macvlan";
      subnets = [ "172.18.0.0/16" ];
      gateways = [ "172.18.0.1" ];
    };

    pods.ha.podConfig = {
      name = "ha";
      networks = [ "ha:mac=02:fd:38:25:58:f9" ];
      ip = "172.18.2.11";
      dns = [ "172.18.0.1" ];
      uidMaps = [ "0:100000:65536" ];
      gidMaps = [ "0:100000:65536" ];
    };

    containers = {
      nginx = {
        unitConfig = {
          After = [ "var-lib-nginx.mount" ];
          Requires = [ "var-lib-nginx.mount" ];
        };
        containerConfig = {
          name = "nginx";
          pod = "ha.pod";
          image = "docker.io/nginxinc/nginx-unprivileged:alpine-slim@sha256:ca2305d71219043ad4cdf91d588b5a4f94d6bc3cd44bfd8667cee0b6c121b712";
          dropCapabilities = ["ALL"];
          addCapabilities = [ "NET_BIND_SERVICE" ];
          noNewPrivileges = true;
          readOnly = true;
          tmpfses = [ "/tmp" ];
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
          image = "ghcr.io/home-assistant/home-assistant:stable@sha256:e876528e4159974e844bbf3555e67ff48d73a78bf432b717dd9d178328230b40";
          # dropCapabilities = ["ALL"];
          addCapabilities = ["FOWNER" "NET_RAW"];
          noNewPrivileges = true;
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
          image = "zwavejs/zwave-js-ui:latest@sha256:52b6ee2c37fa1a3c13a8d8f59b45145b546ec31b5c85d5053e1279fc558c5a1e";
          # dropCapabilities = ["ALL"];
          # addCapabilities = ["FOWNER" "NET_RAW"];
          noNewPrivileges = true;
          # readOnly = true;
          # tmpfses = [ "/var/run" "/tmp" ];
          volumes = [ "/var/lib/zwave/store:/usr/src/app/store" ];
          devices = [ "/dev/serial/by-id/usb-Silicon_Labs_CP2102N_USB_to_UART_Bridge_Controller_e015830c1ba4eb11a4f62a259da30875-if00-port0:/dev/zwave" ];
          environments = {
            TZ = config.time.timeZone;
            TRUST_PROXY = "127.0.0.1";
          };
          environmentFiles = [ "/var/lib/zwave/env.secret" ];
        };
      };
    };
  };
}
