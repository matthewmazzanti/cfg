{ config, flake, ... }: {
  # Create filesystems for different containers in zfs
  fileSystems = {
    "/var/lib/nextcloud" = {
      device = "root-pool/state/services/nextcloud";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };

    "/srv/files" = {
      device = "data-pool/share/files";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };
  };

  virtualisation.quadlet = {
    networks.nextcloud.networkConfig.driver = "bridge";

    ## Define each container
    containers = {
      nextcloud-app = {
        containerConfig = {
          image = flake.lib.images.nextcloud;
          uidMaps = [ "0:300000:65536" ];
          gidMaps = [ "0:300000:65536" ];
          volumes = [
            "/var/lib/nextcloud/html:/var/www/html:rw"
            "/srv/files:/var/www/html/data:rw"
          ];
          networks = [ "nextcloud" ];
        };
      };

      nextcloud-web = {
        unitConfig = {
          wants = [ "nextcloud-app" ];
        };
        containerConfig = {
          image = flake.lib.images.nginx;
          uidMaps = [ "0:300000:65536" ];
          gidMaps = [ "0:300000:65536" ];
          volumes = [
            "${./nginx.conf}:/etc/nginx/nginx.conf:ro"
            "/var/lib/nextcloud/ssl:/etc/nginx/ssl:ro"
            "/var/lib/nextcloud/html:/var/www/html:ro"
            "/srv/files:/var/www/html/data:ro"
          ];
          # publishPorts = ["80:80" "443:443"];
          networks = [ "nextcloud" ];
        };
      };

      nextcloud-cron = {
        unitConfig = {
          wants = [ "nextcloud-app.service" ];
        };
        containerConfig = {
          image = flake.lib.images.nextcloud;
          uidMaps = [ "0:300000:65536" ];
          gidMaps = [ "0:300000:65536" ];
          volumes = [
            "/var/lib/nextcloud/html:/var/www/html:rw"
            "/srv/files:/var/www/html/data:rw"
          ];
          entrypoint = [ "/cron.sh" ];
          networks = [ "nextcloud" ];
        };
      };
    };
  };
}
