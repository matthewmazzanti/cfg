{...}: {
  fileSystems."/var/lib/gitea/repositories" = {
    device = "data-pool/services/git";
    fsType = "zfs";
    options = ["noatime" "nodiratime" ];
  };

  environment.persistence."/persist".directories = [ "/var/lib/gitea" ];

  services.gitea = {
    enable = true;
    settings.server.SSH_PORT = 2222;
    settings.service.DISABLE_REGISTRATION = true;
  };
}
