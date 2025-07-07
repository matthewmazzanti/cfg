{ config, flake, ... }: {
  # Create filesystems for different containers in zfs
  fileSystems = {
    "/var/lib/jellyfin" = {
      device = "root-pool/state/services/jellyfin";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };
  };

  virtualisation.quadlet = {
    networks.jellyfin.networkConfig = {
      driver = "macvlan";
      subnets = [ "172.16.0.0/16" ];
      gateways = [ "172.16.0.1" ];
      ipRanges = [ "172.16.1.12/32" ];
    };

    pods.jellyfin-pod.podConfig = {
      name = "jellyfin-pod";
      networks = [ "jellyfin:mac=a2:d9:5d:37:ef:10" ];
      ip = "172.16.1.12";
      dns = [ "172.16.0.1" ];
      uidMaps = [ "0:100000:65536" ];
      gidMaps = [ "0:100000:65536" ];
    };

    containers = {
      jellyfin-nginx = {
        unitConfig = {
          After = [ "var-lib-jellyfin.mount" ];
          Requires = [ "var-lib-jellyfin.mount" ];
        };
        containerConfig = {
          name = "jellyfin-nginx";
          pod = "jellyfin.pod";
          image = "docker.io/library/nginx:alpine-slim@sha256:e4e764cb35f666f44dd4e1da4291a5f73bb8bff2a9464ccecd8a05a2b7226ad5";
          dropCapabilities = ["ALL"];
          addCapabilities = [ "SETUID" "SETGID" "CHOWN" "NET_BIND_SERVICE" ];
          noNewPrivileges = true;
          # readOnly = true;
          # tmpfses = [ "/var/run" "/tmp" ];
          volumes = [
            "${./nginx.conf}:/etc/nginx/nginx.conf:ro"
            "/var/lib/jellyfin/nginx/ssl:/etc/nginx/ssl:ro"
          ];
          environments.TZ = config.time.timeZone;
        };
      };

      jellyfin = {
        unitConfig = {
          After = [ "var-lib-jellyfin.mount" "srv-share-media.mount" ];
          Requires = [ "var-lib-jellyfin.mount" "srv-share-media.mount" ];
        };
        containerConfig = {
          name = "jellyfin";
          pod = "jellyfin-pod.pod";
          image = "docker.io/jellyfin/jellyfin:unstable@sha256:8581a885d7d554bc36f81bd90c411394bdd685267b1af76c73ed4aedb5edb65e";
          # dropCapabilities = ["ALL"];
          # addCapabilities = [ "FOWNER" "NET_RAW" ];
          noNewPrivileges = true;
          # readOnly = true;
          # tmpfses = [ "/var/run" "/tmp" ];
          volumes = [
            "/var/lib/jellyfin/config:/config:rw"
            "/var/lib/jellyfin/cache:/cache:rw"
            "/srv/share/media:/media:ro"
          ];
          environments.TZ = config.time.timeZone;
        };
      };
    };
  };
}
