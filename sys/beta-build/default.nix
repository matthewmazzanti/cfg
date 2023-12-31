{ pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "23.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };
  users.users.build = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4h5HZCnD2uFkpb8Z/pPQKXrtdV5YU3DG1w+9rOyddy mmazzanti@beta.xi"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOcILRGzPmY2c4QJkuLVF5NhBubrRPZUn96eiABvVFuF root@beta.local"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.extraOptions = ''
    experimental-features = nix-command flakes
    builders-use-substitutes = true
    secret-key-files = /var/cache-priv-key.pem
  '';
  services.nix-serve = {
    enable = true;
    secretKeyFile = "/var/cache-priv-key.pem";
    port = 80;
    openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
  ];
  virtualisation.rosetta.enable = true;
}
