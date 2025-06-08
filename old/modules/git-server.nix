# TODO: Module used anywhere?
{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.usage.git-server;

  hostName = config.networking.hostName;

  gitea = let
    cfg = config.services.gitea;
  in {
    addr = cfg.httpAddress;
    port = toString cfg.httpPort;
    static = cfg.staticRootPath;
  };

  staticUrlPath = "/static";
in {
  options.usage.git-server = {
    enable = mkEnableOption "gitea server";

    deploy = mkOption {
      default = false;
      type = types.bool;
      description = "Whether to deploy gitea server";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [80];

    services = {
      nginx = {
        enable = true;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;

        virtualHosts."git.example.com".locations = let
          gitea = config.services.gitea;
          rootPath = "http://${gitea.httpAddress}:${toString gitea.httpPort}";
        in {
          "/".proxyPass = rootPath;
          "${staticUrlPath}/".alias = "${gitea.static}";
        };
      };

      gitea = {
        enable = true;
        disableRegistration = cfg.deploy;
        database.type = "postgres";
        httpAddress = "127.0.0.1";
        domain = "${hostName}";
        # TODO: This is wrong
        rootUrl = "http://${hostName}.olympus/";
        extraConfig = ''
          STATIC_URL_PREFIX = ${staticUrlPath}
        '';
      };
    };
  };
}
