{ pkgs, modulesPath, flake, ... }: {
  # Not entirely sure what this does, but it definitely does something
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  # Use systemd in initrd
  boot.initrd.systemd.enable = true;

  # Console stuff
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = pkgs.writeText "keymap" ''
    include "${pkgs.kbd}/share/keymaps/i386/qwerty/us.map.gz"
    keycode 58 = Escape
  '';

  # Time zone.
  time.timeZone = "America/New_York";

  # Packages
  environment.systemPackages = with pkgs; [
    # Minimally configured neovim
    flake.packages."nvim/root"
    # Http stuff
    wget curl
    # Misc utils
    ripgrep fd tree jq tmux git openssl htop lsof
    dig netcat nmap

    # Compression
    unzip zip

    # Scripting languages
    python3 uv

    # Installation/debug utils
    e2fsprogs # ext filesystem management, chattr
    gptfdisk # sgdisk
    usbutils # lsusb
    nftables # firewall control
  ];

  # Users may only be specified via nix
  users.mutableUsers = false;
  # Disable root login entirely
  users.users.root.hashedPassword = "!";
  # Create mmazzanti user
  users.users.mmazzanti = {
    isNormalUser = true;
    extraGroups = ["wheel"];
  };

  # Enable zsh
  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Allow ssh from interactive computers
  users.users.mmazzanti.openssh.authorizedKeys.keys = with flake.lib.keys.ssh; [
    beta
    framework
  ];

  # Trust my CA
  security.pki.certificates = [ flake.lib.keys.ca.crt ];

  # Auto cleanup
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 180d";
  nix.optimise.automatic = true;

  # Allow flakes and `nix` command
  nix.extraOptions = "experimental-features = nix-command flakes";

  # State version for all systems
  system.stateVersion = "25.05";
}
