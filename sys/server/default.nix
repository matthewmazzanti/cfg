{ flake, ... }: {
  imports = [
    flake.modules.base
    flake.modules.impermanence
    flake.modules.lanzaboote
    flake.modules.quadlet
    ./hardware.nix
    ./jellyfin
    # ./gitea
  ];

  # Networking
  networking.hostName = "server";

  # ZFS auto-cleanup
  networking.hostId = "a87230c5";
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # Packages
  # environment.systemPackages = with pkgs; [];

  # User config
  users.users.mmazzanti = {
    extraGroups = ["networkmanager" "podman" "dialout"];
    packages = [ flake.packages."nvim/nix" ];
  };

  environment.persistence."/persist".directories = [
    "/var/lib/containers"
    "/var/lib/ssl"
  ];

  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    networks."00-enp7s0" = {
      matchConfig.Name = "enp7s0";
      networkConfig = {
        DHCP = false;
        Address = [ "172.16.1.10/16" ];
        Gateway = [ "172.16.0.1" ];
        DNS = [ "172.16.0.1" ];
        VLAN = [ "enp7s0.18" ];
      };
    };

    netdevs."05-enp7s0.18" = {
      netdevConfig = {
        Name = "enp7s0.18";
        Kind = "vlan";
      };
      vlanConfig.Id = 18;
    };

    networks."05-enp7s0.18" = {
      matchConfig.Name = "enp7s0.18";
    };
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };

  networking.firewall.interfaces.enp7s0.allowedTCPPorts = [ 22 80 443 ];

  services.openssh.listenAddresses = [{
    addr = "172.16.1.10";
  }];

  virtualisation.quadlet.autoEscape = true;
}
