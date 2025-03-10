{ config, dependencies, ... }:
# TODOS:
# - Run containers as non-root
# - More complex configuration/ui-lovelace configuration reloads
let
  images = builtins.fromJSON (builtins.readFile ./images.lock);
  home-assistant-data = "/var/lib/home-assistant";
  zwave-data = "/var/lib/zwave-js";
in {
  # Allow Home Assistant to discover local devices
  # TODO: Fix home assistant/apple tv stuff, configure ports correctly.
  #
  networking.firewall = {
    enable = false;
    # allowedTCPPorts = [ 80 443 ];
  };
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
  };

  # === Home Assistant ===
  virtualisation.oci-containers.containers.home-assistant = {
    image = images.home-assistant.lock;
    serviceName = "home-assistant";
    autoStart = true;
    environment = {
      TZ = config.time.timeZone;
    };
    volumes = [
      "${home-assistant-data}/config:/config"
      "${./home-assistant/configuration.yaml}:/config/configuration.yaml:ro"
      "${dependencies.sliderEntityRow}:/config/www/slider-entity-row:ro"
      "${dependencies.pyscript}:/config/custom_components/pyscript:ro"
    ];
    extraOptions = [ "--network=host" ];
  };
  services.nginx.virtualHosts."home-assistant.iot" = {
    forceSSL = true;
    # TODO: These are manually provisioned, find way to automate
    sslCertificate = "${home-assistant-data}/tls/home-assistant.iot.crt";
    sslCertificateKey = "${home-assistant-data}/tls/home-assistant.iot.key";
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

  # === Zwave JS ===
  virtualisation.oci-containers.containers.zwave-js = {
    image = images.zwave-js.lock;
    serviceName = "zwave-js";
    autoStart = true;
    environment = {
      TZ = config.time.timeZone;
    };
    environmentFiles = [ "${zwave-data}/env.secret" ];
    ports = [ "127.0.0.1:8091:8091" "127.0.0.1:3000:3000" ];
    volumes = [ "${zwave-data}/store:/usr/src/app/store" ];
    extraOptions = [
      "--device=/dev/serial/by-id/usb-Silicon_Labs_CP2102N_USB_to_UART_Bridge_Controller_e015830c1ba4eb11a4f62a259da30875-if00-port0:/dev/zwave"
    ];
  };
  services.nginx.virtualHosts."zwave.iot" = {
    forceSSL = true;
    # TODO: These are manually provisioned, find way to automate
    sslCertificate = "${zwave-data}/tls/zwave.iot.crt";
    sslCertificateKey = "${zwave-data}/tls/zwave.iot.key";
    locations."/" = {
      proxyPass = "http://127.0.0.1:8091";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
  };
}
