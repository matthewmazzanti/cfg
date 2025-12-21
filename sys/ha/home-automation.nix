{ config, flake, ... }: {
  # Bluetooth + BlueZ
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Enable BlueZ userspace experimental features.
        # Required for reliable BLE GATT operations used by SwitchBot
        # (improves LE scanning, connection handling, and write semantics).
        Experimental = true;

        # Enable kernel-side Bluetooth experimental paths.
        # Improves LE connection parameter negotiation and reconnect behavior
        # for devices that rapidly connect/write/disconnect (e.g. SwitchBot).
        KernelExperimental = true;

        # Restrict the controller to Bluetooth Low Energy only.
        # Disables BR/EDR (classic Bluetooth), reducing firmware scheduling
        # contention and improving LE latency on headless automation hosts.
        ControllerMode = "le";

        # Use stable per-device BLE identities instead of rotating addresses.
        # Prevents SwitchBot devices from "disappearing" or being rediscovered
        # after reboot, reducing scan time and connection delays.
        Privacy = "device";

        # Automatically repair broken or dropped BLE pairings using
        # the Just-Works model.
        # SwitchBot devices frequently lose bonding state; this avoids
        # manual re-pairing and prevents silent reconnect failures.
        JustWorksRepairing = "always";
      };
    };
  };

  # Storage for containers
  environment.persistence."/persist".directories = [
    "/var/lib/containers"
    "/var/lib/bluetooth"
  ];

  # Create filesystems for different containers in zfs
  fileSystems = {
    "/var/lib/nginx" = {
      device = "root-pool/state/services/nginx";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };

    "/var/lib/hass" = {
      device = "root-pool/state/services/hass";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };

    "/var/lib/zwave" = {
      device = "root-pool/state/services/zwave";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };
  };

  virtualisation.quadlet = {
    networks.ha.networkConfig = {
      driver = "macvlan";
      subnets = [ "172.18.0.0/16" ];
      gateways = [ "172.18.0.1" ];
      ipRanges  = [ "172.18.2.11/32" ];
    };

    pods.ha.podConfig = {
      name = "ha";
      networks = [ "ha:mac=a2:d9:5d:37:ef:10" ];
      ip = "172.18.2.11";
      dns = [ "172.18.0.1" ];
      # uidMaps = [ "0:100000:65536" ];
      # gidMaps = [ "0:100000:65536" ];
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
          image = flake.lib.images.nginx;
          dropCapabilities = ["ALL"];
          addCapabilities = [ "SETUID" "SETGID" "CHOWN" "NET_BIND_SERVICE" ];
          noNewPrivileges = true;
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
          After = [ "var-lib-hass.mount" "bluetooth.service" ];
          Requires = [ "var-lib-hass.mount" "bluetooth.service" ];
        };
        containerConfig = {
          name = "hass";
          pod = "ha.pod";
          image = flake.lib.images.hass;
          addCapabilities = [ "FOWNER" "NET_RAW" "NET_ADMIN" ];
          noNewPrivileges = true;
          volumes = [
            "/etc/machine-id:/etc/machine-id:ro"
            "/etc/localtime:/etc/localtime:ro"
            "/var/lib/hass:/config:rw"
            "${./configuration.yaml}:/config/configuration.yaml:ro"
            "${flake.inputs.slider-entity-row}:/config/www/slider-entity-row:ro"
            "${./multicast_exec}:/config/custom_components/multicast_exec:ro"
            "/run/dbus/system_bus_socket:/run/dbus/system_bus_socket:ro"
          ];
          environments = {
            TZ = config.time.timeZone;
            DBUS_SYSTEM_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket";
          };
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
          image = flake.lib.images.zwave;
          # dropCapabilities = ["ALL"];
          # addCapabilities = ["FOWNER" "NET_RAW"];
          noNewPrivileges = true;
          # readOnly = true;
          # tmpfses = [ "/var/run" "/tmp" ];
          volumes = [ "/var/lib/zwave/store:/usr/src/app/store" ];
          devices = [ "/dev/serial/by-id/usb-Nabu_Casa_ZWA-2_80B54EE5C748-if00:/dev/zwave" ];
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
