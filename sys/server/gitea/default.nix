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
    networks.gitea.networkConfig.driver = "bridge";

    containers.gitea = {
      unitConfig = {
        After = [ "var-lib-gitea.mount" "srv-git.mount" ];
        Requires = [ "var-lib-gitea.mount" "srv-git.mount" ];
      };
      containerConfig = {
        image = flake.lib.images.gitea;
        name = "gitea";
        volumes = [
          "/etc/localtime:/etc/localtime:ro"
          "/var/lib/gitea/data:/var/lib/gitea:rw"
          "${./app.ini}:/etc/gitea/app.ini:ro"
          "/var/lib/gitea/secrets:/run/secrets:ro"
          "/srv/git:/srv/git:rw"
        ];
        networks = [ "gitea" ];
        ports = [ "127.0.0.1:16001:8000" "172.16.1.10:2222:2222" ];
        environments.TZ = config.time.timeZone;

        uidMaps = [ "0:200000:65536" ];
        gidMaps = [ "0:200000:65536" ];
        dropCapabilities = ["ALL"];
        noNewPrivileges = true;
        readOnly = true;
        tmpfses = [ "/tmp" ];
      };
    };
  };

  networking.firewall.enp7s0.allowedTCPPorts = [ 2222 ];

  services.nginx.virtualHosts."git.lan" = {
    # HTTP → HTTPS redirection
    listen = [
      { addr = "172.16.1.10"; port = 80; }
      { addr = "172.16.1.10"; port = 443; ssl = true; }
    ];
    forceSSL = true;

    ssl = true;
    sslCertificate = "/var/lib/ssl/git.lan/git.lan.crt";
    sslCertificateKey = "/var/lib/ssl/git.lan/git.lan.key";

    locations."/" = {
      proxyPass = "http://127.0.0.1:16001";
      proxyWebsockets = true;
    };
  };
}
