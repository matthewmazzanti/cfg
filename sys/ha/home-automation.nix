{ config, pkgs, flake, ... }:
let
  inherit (config.virtualisation.quadlet) builds;

  # Pin the git commit of pyatv to inject into the Apple TV integration.
  pyatvRef = "9177803dec6a165d4610d5d63fe09562820fccdb";
  pyatvReq = "pyatv @ git+https://github.com/postlund/pyatv@${pyatvRef}";

  # Build context for the hass override image. A dedicated store dir keeps the
  # podman build context to just the Containerfile (no COPY needed).
  hassBuildContext = pkgs.writeTextDir "Containerfile" ''
    FROM ${flake.lib.images.hass}
    RUN apk add --no-cache git \
     && pip install --no-cache-dir --break-system-packages "${pyatvReq}" \
     && python3 -c "import importlib.util,json,pathlib; r=pathlib.Path(importlib.util.find_spec('homeassistant').submodule_search_locations[0])/'components/apple_tv/manifest.json'; d=json.loads(r.read_text()); d['requirements']=['${pyatvReq}' if x.lower().startswith('pyatv') else x for x in d['requirements']]; r.write_text(json.dumps(d,indent=2)+chr(10))"
  '';
in {
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Storage for containers
  environment.persistence."/persist".directories = [ "/var/lib/containers" ];

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
    };

    # Override hass stable with a custom-built image that injects a git
    # version of pyatv into the Apple TV integration manifest.
    #
    # Workaround for the Apple TV power off / power state issue introduced by
    # tvOS 26.4: the Companion protocol stopped reliably reporting power state
    # ("Could not fetch SystemStatus, power_state will not work"). The pinned
    # pyatv commit carries the fix from
    # https://github.com/postlund/pyatv/pull/2855 (TVRCSessionStart handshake +
    # non-null system info identifier). Drop this override once a hass stable
    # release ships a pyatv version that includes the fix.
    builds.hass.buildConfig.file = "${hassBuildContext}/Containerfile";

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
          image = builds.hass.ref;
          addCapabilities = [ "FOWNER" "NET_RAW" ];
          noNewPrivileges = true;
          volumes = [
            "/etc/machine-id:/etc/machine-id:ro"
            "/etc/localtime:/etc/localtime:ro"
            "/var/lib/hass:/config:rw"
            "${./configuration.yaml}:/config/configuration.yaml:ro"
            "${./macros.jinja}:/config/custom_templates/macros.jinja:ro"
            "${./multicast_exec}:/config/custom_components/multicast_exec:ro"
            "${flake.inputs.slider-entity-row}:/config/www/slider-entity-row:ro"
            "${flake.inputs.switchbot-ble}/custom_components/switchbot:/config/custom_components/switchbot:ro"
          ];
          environments = {
            TZ = config.time.timeZone;
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
          noNewPrivileges = true;
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
