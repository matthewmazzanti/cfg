{
  config,
  flake,
  ...
}:
# TODOS:
# - Run containers as non-root
# - More complex configuration/ui-lovelace configuration reloads
let
  hassData = "/persist/containers/hass";
  zwaveData = "/persist/containers/zwave";
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
  users.groups.hass = {};
  users.users.hass = {
    isSystemUser = true;
    group = "hass";
    home = "/var/lib/hass";
    createHome = true;
    subUidRanges = [ { count = 65536; } ];
    subGidRanges = [ { count = 65536; } ];
  };

  virtualisation.oci-containers.containers.hass = {
    # Tag: ghcr.io/home-assistant/home-assistant:stable
    image = "ghcr.io/home-assistant/home-assistant@sha256:e207929bdf5dc95db43c618b877364e99f7ad506ec5440aeef80d5c9c1cae668";
    serviceName = "hass";
    autoStart = true;
    environment.TZ = config.time.timeZone;
    volumes = [
      "${hassData}/config:/config"
      "${./hass-config/configuration.yaml}:/config/configuration.yaml:ro"
      "${flake.inputs.slider-entity-row}:/config/www/slider-entity-row:ro"
      "${flake.inputs.pyscript}/custom_components/pyscript:/config/custom_components/pyscript:ro"
    ];
    extraOptions = ["--network=host"];
    podman.user = "hass";
  };
  services.nginx.virtualHosts."hass.iot" = {
    forceSSL = true;
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
    # Tag: zwavejs/zwave-js-ui:latest
    image = "zwavejs/zwave-js-ui@sha256:52b6ee2c37fa1a3c13a8d8f59b45145b546ec31b5c85d5053e1279fc558c5a1e";
    serviceName = "zwave";
    autoStart = true;
    environment.TZ = config.time.timeZone;
    environmentFiles = ["${zwaveData}/env.secret"];
    ports = ["127.0.0.1:8091:8091" "127.0.0.1:3000:3000"];
    volumes = ["${zwaveData}/store:/usr/src/app/store"];
    extraOptions = ["--device=/dev/serial/by-id/usb-Silicon_Labs_CP2102N_USB_to_UART_Bridge_Controller_e015830c1ba4eb11a4f62a259da30875-if00-port0:/dev/zwave"];
  };
  services.nginx.virtualHosts."zwave.iot" = {
    forceSSL = true;
    sslCertificate = "${zwaveData}/tls/zwave.iot.crt";
    sslCertificateKey = "${zwaveData}/tls/zwave.iot.key";
    locations."/" = {
      proxyPass = "http://127.0.0.1:8091";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
  };
}
