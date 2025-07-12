{ config, flake, ... }: {
  # Create filesystems for different containers in zfs
  fileSystems = {
    "/var/lib/gitea" = {
      device = "root-pool/state/services/gitea";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };

    "/srv/git" = {
      device = "data-pool/share/git";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };
  };

  virtualisation.quadlet = {
    networks.gitea.networkConfig = {
      driver = "macvlan";
      subnets = [ "172.16.0.0/16" ];
      gateways = [ "172.16.0.1" ];
      ipRanges = [ "172.16.1.12/32" ];
      options = [ "parent=enp7s0" ];
    };

    pods.gitea-pod.podConfig = {
      name = "gitea-pod";
      networks = [ "gitea:mac=52:36:82:65:e6:72" ];
      ip = "172.16.1.12";
      dns = [ "172.16.0.1" ];
      uidMaps = [ "0:200000:65536" ];
      gidMaps = [ "0:200000:65536" ];
    };

    containers = {
      gitea-nginx = {
        unitConfig = {
          After = [ "var-lib-gitea.mount" ];
          Requires = [ "var-lib-gitea.mount" ];
        };
        containerConfig = {
          name = "gitea-nginx";
          pod = "gitea-pod.pod";
          image = flake.lib.images.nginx;
          dropCapabilities = ["ALL"];
          addCapabilities = [ "SETUID" "SETGID" "CHOWN" "NET_BIND_SERVICE" ];
          noNewPrivileges = true;
          # readOnly = true;
          # tmpfses = [ "/var/run" "/tmp" ];
          volumes = [
            "${./nginx.conf}:/etc/nginx/nginx.conf:ro"
            "/var/lib/gitea/nginx/ssl:/etc/nginx/ssl:ro"
          ];
          environments.TZ = config.time.timeZone;
        };
      };

      gitea = {
        unitConfig = {
          After = [ "var-lib-gitea.mount" "srv-git.mount" ];
          Requires = [ "var-lib-gitea.mount" "srv-git.mount" ];
        };
        containerConfig = {
          name = "gitea";
          pod = "gitea-pod.pod";
          image = flake.lib.images.gitea;
          dropCapabilities = ["ALL"];
          addCapabilities = [ "NET_BIND_SERVICE" ];
          sysctl = { "net.ipv4.ip_unprivileged_port_start" = "1024"; };
          noNewPrivileges = true;
          # readOnly = true;
          # tmpfses = [ "/var/run" "/tmp" ];
          volumes = [
            "/etc/localtime:/etc/localtime:ro"
            "/var/lib/gitea/data:/var/lib/gitea:rw"
            "${./app.ini}:/etc/gitea/app.ini:ro"
            "/var/lib/gitea/secrets:/run/secrets:ro"
            "/srv/git:/var/lib/gitea/git:rw"
          ];
          environments.TZ = config.time.timeZone;
        };
      };
    };
  };
}
