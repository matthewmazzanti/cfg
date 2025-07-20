{ config, flake, ... }: {
  # Create filesystems for different containers in zfs
  fileSystems = {
    "/var/lib/seafile" = {
      device = "data-pool/services/seafile";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };
  };

  virtualisation.quadlet = {
    networks.seafile-net.networkConfig.driver = "bridge";

    containers = {
      seafile-db = {
        unitConfig = {
          After = [ "var-lib-seafile.mount" ];
          Requires = [ "var-lib-seafile.mount" ];
        };
        containerConfig = {
          image = flake.lib.images.mariadb;
          name = "seafile-mysql";
          environments = {
            MYSQL_LOG_CONSOLE = "true";
            MARIADB_AUTO_UPGRADE = "1";
          };
          # TODO: Env file
          # MYSQL_ROOT_PASSWORD = "";
          environmentFiles = [ "/var/lib/seafile/db.env" ];
          volumes = [ "/var/lib/seafile/db:/var/lib/mysql:rw" ];
          networks = [ "seafile-net" ];
        };
      };

      seafile-cache = {
        containerConfig = {
          image = flake.lib.images.redis;
          name = "seafile-redis";
          # TODO: Env file
          # REDIS_PASSWORD = "";
          environmentFiles = [ "/var/lib/seafile/cache.env" ];
          networks = [ "seafile-net" ];
        };
      };

      seafile = {
        unitConfig = {
          After = [ "var-lib-seafile.mount" "seafile-db" "seafile-cache" ];
          Requires = [ "var-lib-seafile.mount" ];
        };
        containerConfig = {
          image = flake.lib.images.seafile;
          name = "seafile";
          publishPorts = [ "127.0.0.1:16002:80" ];
          volumes = [ "/var/lib/seafile/data:/shared:rw" ];
          environments = {
            TIME_ZONE = config.time.timeZone;
            SEAFILE_MYSQL_DB_HOST = "db";
            SEAFILE_MYSQL_DB_PORT = "3306";
            SEAFILE_MYSQL_DB_USER = "seafile";
            SEAFILE_MYSQL_DB_CCNET_DB_NAME = "ccnet_db";
            SEAFILE_MYSQL_DB_SEAFILE_DB_NAME = "seafile_db";
            SEAFILE_MYSQL_DB_SEAHUB_DB_NAME = "seahub_db";
            SEAFILE_SERVER_HOSTNAME = "files.lan";
            SEAFILE_SERVER_PROTOCOL = "http";
            SITE_ROOT = "/";
            NON_ROOT = "false";
            SEAFILE_LOG_TO_STDOUT = "true";
            ENABLE_SEADOC = "false";
            CACHE_PROVIDER = "redis";
            REDIS_HOST = "redis";
            REDIS_PORT = "6379";
          };
          # TODO: Env file
          # SEAFILE_MYSQL_DB_PASSWORD = "";
          # INIT_SEAFILE_MYSQL_ROOT_PASSWORD = "";
          # INIT_SEAFILE_ADMIN_EMAIL = "me@example.com";
          # INIT_SEAFILE_ADMIN_PASSWORD = "asecret";
          # REDIS_PASSWORD = "";
          # JWT_PRIVATE_KEY = "";
          environmentFiles = [ "/var/lib/seafile/seafile.env" ];

          networks = [ "seafile-net" ];
        };
      };
    };
  };
}
