{ config, ... }:
# TODOS:
# - Run containers as non-root
# - More complex configuration/ui-lovelace configuration reloads
let
  images = builtins.fromJSON (builtins.readFile ./images.lock);
in {
  # Allow Home Assistant to discover local devices
  networking.firewall.enable = false;

  virtualisation.oci-containers = {
    containers = {
      home-assistant = {
        image = images.home-assistant.lock;
        autoStart = true;
        environment = {
          TZ = config.time.timeZone;
        };
        volumes = [
          "/var/lib/home-assistant/config:/config"
          "${./home-assistant/configuration.yaml}:/config/configuration.yaml:ro"
        ];
        extraOptions = [
          "--network=host"
        ];
      };
      zwave-js = {
        image = images.zwave-js.lock;
        autoStart = true;
        environment = {
          TZ = config.time.timeZone;
        };
        environmentFiles = [
          "/var/lib/zwave-js/env.secret"
        ];
        ports = [
          "0.0.0.0:8091:8091"
          "127.0.0.1:3000:3000"
        ];
        volumes = [ "/var/lib/zwave-js/store:/usr/src/app/store" ];
        extraOptions = [
          "--device=/dev/serial/by-id/usb-Silicon_Labs_CP2102N_USB_to_UART_Bridge_Controller_e015830c1ba4eb11a4f62a259da30875-if00-port0:/dev/zwave"
        ];
      };
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    # recommendedTlsSettings = true; 
    virtualHosts."home-assistant.iot" = {
      # forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8123";
        proxyWebsockets = true;
        extraConfig =
          # required when the server wants to use HTTP Authentication
          "proxy_pass_header Authorization;"
          ;
      };
    };
  };
}
