{ config, flake, ... }: let
  hostname = "idm.lan";
  port = "16000";
in {
  # Create filesystems for different containers in zfs
  fileSystems = {
    "/var/lib/kanidm" = {
      device = "pool/services/kanidm";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };
  };

  virtualisation.quadlet = {
    networks.kanidm.networkConfig.driver = "bridge";

    containers.kanidm = {
      unitConfig = {
        After = [ "var-lib-kanidm.mount" ];
        Requires = [ "var-lib-kanidm.mount" ];
      };
      containerConfig = {
        image = flake.lib.images.kanidm;
        name = "kanidm";
        volumes = [
          "/etc/localtime:/etc/localtime:ro"
          "/var/lib/kanidm/data:/data:rw"
          "${./config.toml}:/data/config/config.toml:ro:ro"
        ];
        networks = [ "kanidm" ];
        ports = [ "127.0.0.1:${port}:8000" ];
        environments.TZ = config.time.timeZone;
      };
    };
  };

  services.nginx.virtualHosts."${hostname}" = {
    # HTTP → HTTPS redirection
    listen = [
      { addr = "172.16.1.10"; port = 80; }
      { addr = "172.16.1.10"; port = 443; ssl = true; }
    ];
    forceSSL = true;

    ssl = true;
    sslCertificate = "/var/lib/ssl/${hostname}/${hostname}.crt";
    sslCertificateKey = "/var/lib/ssl/${hostname}/${hostname}.key";

    locations."/" = {
      proxyPass = "http://127.0.0.1:${port}";
      proxyWebsockets = true;
    };
  };
}
