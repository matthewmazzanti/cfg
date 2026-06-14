{ config, lib, pkgs, flake, ... }:
let
  inherit (config.virtualisation.quadlet) builds;
in {
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Storage for containers
  environment.persistence."/persist".directories = [ "/var/lib/containers" ];

  # Seed the dashboard into .storage before HA starts, from the nix store.
  # PartOf hass.service so a `systemctl restart hass` re-applies the baseline
  # first (resetting any live API/UI edits to the committed layout).
  systemd.services.hass-lovelace-seed = let
    # Bake the repo dashboard YAML into the JSON envelope HA stores for the named
    # `lovelace` dashboard (.storage/lovelace.lovelace), at build time (no runtime
    # yq needed). nix is the baseline source of truth for the layout.
    lovelaceConfig = pkgs.runCommand "lovelace.lovelace.json" {
      nativeBuildInputs = [ pkgs.yq-go ];
    } ''
      yq -o=json \
        '{"version": 1, "minor_version": 1, "key": "lovelace.lovelace", "data": {"config": .}}' \
        ${./ui-lovelace.yaml} > "$out"
    '';

    # Drop the baked config straight from the store into .storage before HA starts.
    # The dashboard stays storage-mode (UI-editable); edits and `just push-ui`
    # changes (which go through HA's API) reset to this baseline on the next hass
    # restart / rebuild.
    seedLovelace = pkgs.writeShellApplication {
      name = "hass-seed-lovelace";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        install -d -m700 /var/lib/hass/.storage
        install -m600 ${lovelaceConfig} /var/lib/hass/.storage/lovelace.lovelace
        chown --reference=/var/lib/hass /var/lib/hass/.storage/lovelace.lovelace
      '';
    };
  in {
    description = "Seed HA Lovelace dashboard into .storage before HA starts";
    after = [ "var-lib-hass.mount" ];
    requires = [ "var-lib-hass.mount" ];
    before = [ "hass.service" ];
    partOf = [ "hass.service" ];
    wantedBy = [ "hass.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.getExe seedLovelace;
    };
  };

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
    builds.hass.buildConfig.file = let
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
    in "${hassBuildContext}/Containerfile";

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
