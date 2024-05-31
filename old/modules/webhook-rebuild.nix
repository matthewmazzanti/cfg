{ pkgs, lib, config,... }:

with lib;

let
  cfg = config.usage.webhook-rebuild;

  webhook-config = pkgs.writeText "webhook-config" (builtins.toJSON [{
    id = "rebuild";
    execute-command = "${webhook-nix-rebuild}";
  }]);

  webhook-nix-rebuild = pkgs.writeShellScript "webhook-nix-rebuild" ''
    set -e
    ${pkgs.git}/bin/git pull --verify-signatures
    ${config.system.build.nixos-rebuild}/bin/nixos-rebuild switch
  '';

in {
  options.usage.webhook-rebuild = {
    enable = mkEnableOption "webhook rebuild service";
  };

  config = mkIf cfg.enable {
    systemd.services.webhook-rebuild = {
      description = "Rebuild Nixos Webhook";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.gnupg ];
      environment = {
        inherit (config.environment.sessionVariables) NIX_PATH;
        HOME = "/root";
      };

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        WorkingDirectory = /etc/nixos;
        ExecStart = ''
            ${pkgs.webhook}/bin/webhook \
            -hooks ${webhook-config} \
            -ip localhost -verbose
        '';
      };
    };
  };
}
