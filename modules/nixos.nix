{ pkgs, flake, ... }: {
  # Console stuff
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # Time zone.
  time.timeZone = "America/New_York";

  # Packages
  environment.systemPackages = with pkgs; [
    # Minimally configured neovim
    flake.packages."nvim/root"
    # Http stuff
    wget curl httpie
    # Misc utils
    ripgrep fd git tree jq tmux openssl

    # Compression
    unzip zip

    # Scripting languages
    python3
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
    lambda
    beta
    framework
  ];

  # Trust my CA
  security.pki.certificates = [flake.lib.keys.ca.crt];

  # Allow flakes and `nix` command
  nix.extraOptions = "experimental-features = nix-command flakes";
}
