{ config, haDeps, ... }:
# TODOS:
# - Run containers as non-root
# - More complex configuration/ui-lovelace configuration reloads
let
  images = builtins.fromJSON (builtins.readFile ./images.lock);
  hassData = "/var/lib/hass";
  zwaveData = "/var/lib/zwave";
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
  virtualisation.oci-containers.containers.hass = {
    image = images.hass.lock;
    serviceName = "hass";
    autoStart = true;
    environment.TZ = config.time.timeZone;
    volumes = [
      "${hassData}/config:/config"
      "${./hass-config/configuration.yaml}:/config/configuration.yaml:ro"
      "${haDeps.slider-entity-row}:/config/www/slider-entity-row:ro"
      "${haDeps.pyscript}/custom_components/pyscript:/config/custom_components/pyscript:ro"
    ];
    extraOptions = [ "--network=host" ];
  };
  services.nginx.virtualHosts."hass.iot" = {
    forceSSL = true;
    # TODO: These are manually provisioned, find way to automate
    sslCertificate = "${hassData}/tls/hass.iot.crt";
    sslCertificateKey = "${hassData}/tls/hass.iot.key";
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
  virtualisation.oci-containers.containers.zwave = {
    image = images.zwave.lock;
    serviceName = "zwave";
    autoStart = true;
    environment.TZ = config.time.timeZone;
    environmentFiles = [ "${zwaveData}/env.secret" ];
    ports = [ "127.0.0.1:8091:8091" "127.0.0.1:3000:3000" ];
    volumes = [ "${zwaveData}/store:/usr/src/app/store" ];
    extraOptions = [ "--device=/dev/serial/by-id/usb-Silicon_Labs_CP2102N_USB_to_UART_Bridge_Controller_e015830c1ba4eb11a4f62a259da30875-if00-port0:/dev/zwave" ];
  };
  services.nginx.virtualHosts."zwave.iot" = {
    forceSSL = true;
    # TODO: These are manually provisioned, find way to automate
    sslCertificate = "${zwaveData}/tls/zwave.iot.crt";
    sslCertificateKey = "${zwaveData}/tls/zwave.iot.key";
    locations."/" = {
      proxyPass = "http://127.0.0.1:8091";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
  };
}
