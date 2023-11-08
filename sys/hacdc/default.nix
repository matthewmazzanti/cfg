{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;


  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.hacdc = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      firefox
      tree
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4h5HZCnD2uFkpb8Z/pPQKXrtdV5YU3DG1w+9rOyddy mmazzanti@beta.xi"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    wget
  ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  system.stateVersion = "23.05";
}
