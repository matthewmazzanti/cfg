{ config, flake, ... }: {
  # Create filesystems for different containers in zfs
  fileSystems = {
    "/var/lib/owncloud" = {
      device = "root-pool/state/services/owncloud";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };
  };

  virtualisation.quadlet = {
    networks.owncloud.networkConfig.driver = "bridge";

    containers = {
      owncloud-server = {
        unitConfig = {
          After = [ "var-lib-owncloud.mount" ];
          Requires = [ "var-lib-owncloud.mount" ];
        };
        containerConfig = {
          image = flake.lib.images.owncloud;
          name = "owncloud";
          volumes = [
            "/etc/localtime:/etc/localtime:ro"
            "/var/lib/owncloud/data:/mnt/data:rw"
          ];
          networks = [ "owncloud" ];
          publishPorts = [ "127.0.0.1:16002:8080" ];
          environments = {
            TZ = config.time.timeZone;
            OWNCLOUD_DOMAIN = "files.lan";
            OWNCLOUD_TRUSTED_DOMAINS = "files.lan";
            OWNCLOUD_DB_TYPE = "pgsql";
            OWNCLOUD_DB_NAME = "owncloud";
            OWNCLOUD_DB_USERNAME = "owncloud";
            OWNCLOUD_DB_HOST = "owncloud-db";
            OWNCLOUD_REDIS_ENABLED = "true";
            OWNCLOUD_REDIS_HOST = "owncloud-cache";
          };
          # TODO: Env file
          # OWNCLOUD_DB_PASSWORD = "owncloud";
          # OWNCLOUD_ADMIN_USERNAME = ${ADMIN_USERNAME};
          # OWNCLOUD_ADMIN_PASSWORD = ${ADMIN_PASSWORD};
          environmentFiles = [ "/var/lib/owncloud/owncloud.env" ];
          healthCmd = "/usr/bin/healthcheck";
          healthInterval = "30s";
          healthTimeout = "10s";
          healthRetries = 5;
        };
      };

      owncloud-db = {
        unitConfig = {
          After = [ "var-lib-owncloud.mount" ];
          Requires = [ "var-lib-owncloud.mount" ];
        };
        containerConfig = {
          image = flake.lib.images.postgres;
          name = "owncloud-db";
          environments = {
            POSTGRES_DB = "owncloud";
            POSTGRES_USER = "owncloud";
          };
          # POSTGRES_PASSWORD = "owncloud";
          environmentFiles = [ "/var/lib/owncloud/db.env" ];
          volumes = [
            "/var/lib/owncloud/db:/var/lib/postgresql/data:rw"
          ];
          healthCmd = builtins.toJSON ["pg_isready" "-U" "owncloud" ];
          healthInterval = "10s";
          healthTimeout = "5s";
          healthRetries = 5;
        };
      };

      owncloud-cache = {
        unitConfig = {
          After = [ "var-lib-owncloud.mount" ];
          Requires = [ "var-lib-owncloud.mount" ];
        };
        containerConfig = {
          image = flake.lib.images.redis;
          name = "owncloud-cache";
          exec = ["--databases" "1"];
          volumes = [ "/var/lib/owncloud/cache:/data:rw" ];
          healthCmd = builtins.toJSON [ "redis-cli" "ping" ];
          healthInterval = "10s";
          healthTimeout = "5s";
          healthRetries = 5;
        };
      };
    };
  };

  /*
  networking.firewall.interfaces.enp7s0.allowedTCPPorts = [ 2222 ];

  services.nginx.virtualHosts."git.lan" = {
    # HTTP → HTTPS redirection
    listen = [
      { addr = "172.16.1.10"; port = 80; }
      { addr = "172.16.1.10"; port = 443; ssl = true; }
    ];
    forceSSL = true;

    sslCertificate = "/var/lib/ssl/git.lan/git.lan.crt";
    sslCertificateKey = "/var/lib/ssl/git.lan/git.lan.key";

    locations."/" = {
      proxyPass = "http://127.0.0.1:16001";
      proxyWebsockets = true;
    };
  };
  */
}
