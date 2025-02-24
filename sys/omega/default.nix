{ config, pkgs, ... }:
let
  hostName = "omega";
in {
  imports = [ ./hardware.nix ../../old/modules ];

  nixpkgs.config.allowUnfree = true;
  # TODO: nix 2.4 broke nix-serve. Use this until this
  # https://github.com/NixOS/nix/pull/5635 backport lands on nixpkgs
  nixpkgs.overlays = [(_: super: {
    nix-serve = super.nix-serve.override { nix = super.nix_2_3; };
  })];

  boot = {
    tmp.cleanOnBoot = true;
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 10;
      efi.canTouchEfiVariables = true;
    };
    binfmt.emulatedSystems = ["aarch64-linux"];
  };

  networking = {
    hostId = "031e21a5";
    hostName = hostName;
    useDHCP = true;
    firewall = {
      allowedTCPPorts = [ 80 443 3005 8324 32400 32469 ];
      allowedUDPPorts = [ 1900 5353 32410 32412 32413 32414 40000 ];
    };
    interfaces.enp7s0.wakeOnLan.enable = true;
  };

  services = {
    nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      # Only allow PFS-enabled ciphers with AES256
      sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";

      commonHttpConfig = ''
        # Add HSTS header with preloading to HTTPS requests.
        # Adding this header to HTTP requests is discouraged
        map $scheme $hsts_header {
            https   "max-age=31536000; includeSubdomains; preload";
        }

        add_header Strict-Transport-Security $hsts_header;

        # Enable CSP for your services.
        #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

        # Minimize information leaked to other domains
        add_header 'Referrer-Policy' 'origin-when-cross-origin';

        # Disable embedding as a frame
        add_header X-Frame-Options DENY;

        # Prevent injection of code in other mime types (XSS Attacks)
        add_header X-Content-Type-Options nosniff;

        # Enable XSS protection of the browser.
        # May be unnecessary when CSP is configured properly (see above)
        add_header X-XSS-Protection "1; mode=block";

        # This might create errors
        proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
      '';

      # TODO: Make this into a function
      virtualHosts = let
        nginxPath = "/var/lib/nginx";
      in {
        "git.${hostName}.xi" = let
          gitea = config.services.gitea;
          rootPath = "http://${gitea.httpAddress}:${toString gitea.httpPort}";
        in {
          forceSSL = true;
          sslCertificate = "/var/lib/nginx/git.omega.xi/git.omega.xi.crt";
          sslCertificateKey = "/var/lib/nginx/git.omega.xi/git.omega.xi.key";
          locations."/".proxyPass = rootPath;
        };

        "cache.${hostName}.xi" = {
          forceSSL = true;
          sslCertificate = "/var/lib/nginx/cache.omega.xi/cache.omega.xi.crt";
          sslCertificateKey = "/var/lib/nginx/cache.omega.xi/cache.omega.xi.key";
          locations."/".proxyPass = "http://localhost:5000";
        };
      };
    };

    gitea = {
      enable = true;
      disableRegistration = true;
      httpAddress = "127.0.0.1";
      domain = "git.${hostName}.xi";
      rootUrl = "https://git.${hostName}.xi";

      settings = {
        ui.DEFAULT_THEME = "arc-green";
      };
    };

    nix-serve = {
      enable = true;
      secretKeyFile = "/var/lib/nix-serve/cache-priv-key.pem";
    };

    plex.enable = true;
  };

  systemd = {
    timers.shutdown-timer = {
      wantedBy = [ "timers.target" ];
      partOf = [ "shutdown-timer.service" ];
      timerConfig.OnCalendar = "*-*-* 22:30:00";
    };

    services.shutdown-timer = {
      serviceConfig.Type = "oneshot";
      script = ''
        systemctl poweroff
      '';
    };
  };

  system.stateVersion = pkgs.lib.mkForce "21.05";
}
