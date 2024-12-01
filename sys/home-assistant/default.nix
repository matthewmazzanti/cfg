{ pkgs, ... }:
{
  imports = [ ./hardware.nix ];

  nix.extraOptions = "experimental-features = nix-command flakes";

  networking.hostName = "home-assistant";

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  environment.systemPackages = with pkgs; [
    neovim
    wget
    curl
    httpie
    ripgrep
    fd
    git
    # Raspberry pi specific stuff
    libraspberrypi
    raspberrypi-eeprom
    (pkgs.callPackage ./install-firmware.nix {}).installScript
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;

  users.users.mmazzanti = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "dialout" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4h5HZCnD2uFkpb8Z/pPQKXrtdV5YU3DG1w+9rOyddy mmazzanti@beta.xi"
    ];
  };

  system.stateVersion = "25.05";
}
