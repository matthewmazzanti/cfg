{ flake, ... }: {
  # Create filesystems for different containers in zfs
  fileSystems = {
    "/srv/wiki" = {
      device = "data-pool/share/wiki";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };
  };

  virtualisation.quadlet = {
    networks.kiwix.networkConfig.driver = "bridge";

    containers.kiwix = {
      unitConfig = {
        After = [ "srv-wiki.mount" ];
        Requires = [ "srv-wiki.mount" ];
      };
      containerConfig = {
        image = flake.lib.images.kiwix;
        name = "kiwix";
        volumes = [ "/srv/wiki:/data:ro" ];
        networks = [ "kiwix" ];
        publishPorts = [ "127.0.0.1:16002:8080" ];
        exec = [ "*.zim" ];

        uidMaps = [ "0:300000:65536" ];
        gidMaps = [ "0:300000:65536" ];
        dropCapabilities = ["ALL"];
        noNewPrivileges = true;
        readOnly = true;
        tmpfses = [ "/tmp" ];
      };
    };
  };

  services.nginx.virtualHosts."wiki.lan" = {
    # HTTP → HTTPS redirection
    listen = [
      { addr = "172.16.1.10"; port = 80; }
      { addr = "172.16.1.10"; port = 443; ssl = true; }
    ];
    forceSSL = true;

    sslCertificate = "/var/lib/ssl/wiki.lan/wiki.lan.crt";
    sslCertificateKey = "/var/lib/ssl/wiki.lan/wiki.lan.key";

    locations."/" = {
      proxyPass = "http://127.0.0.1:16002";
      proxyWebsockets = true;
    };
  };
}
