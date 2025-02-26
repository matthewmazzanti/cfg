{ config, ... }:
# TODOS:
# - Run containers as non-root
# - More complex configuration/ui-lovelace configuration reloads
let
  images = builtins.fromJSON (builtins.readFile ./images.lock);
in {
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
        extraOptions = [ "--network=host" ];
      };
      zwave-js = {
        image = images.zwave-js.lock;
        autoStart = true;
        environment = {
          TZ = config.time.timeZone;
        };
        environmentFiles = [ "/var/lib/zwave-js/env.secret" ];
        ports = [ "127.0.0.1:8091:8091" "127.0.0.1:3000:3000" ];
        volumes = [ "/var/lib/zwave-js/store:/usr/src/app/store" ];
        extraOptions = [
          "--device=/dev/serial/by-id/usb-Silicon_Labs_CP2102N_USB_to_UART_Bridge_Controller_e015830c1ba4eb11a4f62a259da30875-if00-port0:/dev/zwave"
        ];
      };
    };
  };

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      "home-assistant.iot" = {
        forceSSL = true;
        sslCertificate = "/var/lib/home-assistant/tls/home-assistant.iot.crt";
        sslCertificateKey = "/var/lib/home-assistant/tls/home-assistant.iot.key";
        locations."/" = {
          proxyPass = "http://127.0.0.1:8123";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            # Enabling this will make all requests give 400 error
            # proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
          '';
        };
      };
      "zwave.iot" = {
        forceSSL = true;
        sslCertificate = "/var/lib/zwave-js/tls/zwave.iot.crt";
        sslCertificateKey = "/var/lib/zwave-js/tls/zwave.iot.key";
        locations."/" = {
          proxyPass = "http://127.0.0.1:8091";
          proxyWebsockets = true;
          recommendedProxySettings = true;
        };
      };
    };
  };
}
