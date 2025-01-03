{ config, ... }:
let
  images = builtins.fromJSON "images.lock";
in {
  # Homeassistant stuff
  networking.firewall.allowedTCPPorts = [ 8123 8091 ];

  virtualisation = {
    podman.enable = true;
    oci-containers = {
      backend = "podman";
      containers = {
        home-assistant = {
          image = images.home-assistant.lock;
          autoStart = true;
          environment = {
            TZ = config.time.timeZone;
          };
          ports = [ "0.0.0.0:8123:8123" ];
          volumes = ["/var/lib/home-assistant/config:/config"];
          extraOptions = [
            "--privileged"
            "--network=host"
          ];
        };
        /*
        zwave-js = {
          image = "zwavejs/zwave-js-ui:latest";
          autoStart = true;
          environment = {
            TZ = config.time.timeZone;
            ZWAVEJS_EXTERNAL_CONFIG = "/usr/src/app/store/.config-db";
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
        */
      };
    };
  };
}
