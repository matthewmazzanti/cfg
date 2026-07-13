{ config, lib, pkgs, modulesPath, flake, ... }: {
  # Not entirely sure what this does, but it definitely does something
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./zsh.nix
  ];

  # Use systemd in initrd
  boot.initrd.systemd.enable = true;

  # Kernel/zfs pinned explicitly (in lib/pins.json) so a nixpkgs bump can't
  # silently regress them under our ZFS pools. `bump-kernel` (run by `just
  # update`) advances the pins forward-only to the newest ZFS-compatible LTS
  # kernel -- LTS so ZFS (which lags mainline) never strands us at an EOL, the
  # way non-LTS 7.0 did.
  boot.kernelPackages = pkgs.linuxKernel.packages.${flake.lib.pins.kernel.attr};
  boot.zfs.package = pkgs.${flake.lib.pins.zfs.attr};
  boot.zfs.forceImportRoot = false;

  # Console stuff
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = pkgs.writeText "keymap" ''
    include "${pkgs.kbd}/share/keymaps/i386/qwerty/us.map.gz"
    keycode 58 = Escape
  '';
  # Gruvbox dark palette for the Linux virtual terminal (colors 0-15). NixOS
  # passes these as vt.default_{red,grn,blu} kernel params, so the kernel applies
  # them when it brings up the VT -- before initrd -- no earlySetup needed.
  console.colors = [
    "282828" # black
    "cc241d" # red
    "98971a" # green
    "d79921" # yellow
    "458588" # blue
    "b16286" # magenta
    "689d6a" # cyan
    "a89984" # white
    "928374" # bright black
    "fb4934" # bright red
    "b8bb26" # bright green
    "fabd2f" # bright yellow
    "83a598" # bright blue
    "d3869b" # bright magenta
    "8ec07c" # bright cyan
    "ebdbb2" # bright white
  ];

  # The kernel hands VT logins TERM=linux, whose terminfo declares colors#8 --
  # so anything asking for colors 8-15 (the bright half of the palette above)
  # gets \e[39m "default foreground" and the color is lost. The console can show
  # all 16; the linux-16color entry maps 8-15 onto its bold-attribute brights.
  # agetty takes its term-type from $TERM, so setting it here makes login export
  # linux-16color for the whole VT session, before any shell runs. autovt@ is a
  # symlink to getty@, so on-demand VTs are covered too.
  systemd.services."getty@".environment.TERM = "linux-16color";

  # \l is the tty (agetty issue escape); nixos.label is the version string.
  # ''\e emits a literal ESC byte for ANSI color (agetty passes it through
  # untouched — only backslash escapes like \l get interpreted). Hostname is
  # dropped: the login prompt already shows it. Set /etc/issue directly rather
  # than via getty.greetingLine, whose templating stitches in blank lines.
  environment.etc.issue.text = lib.mkForce ''
    [1;34mNixOS[0m ${config.system.nixos.label} [2m(\l)[0m

  '';

  # Time zone.
  time.timeZone = "America/New_York";

  # Packages
  environment.systemPackages = with pkgs; [
    flake.packages.home-manager
    # Minimally configured nvim
    flake.packages."nvim/root"
    # Configured pager (shadows the deprioritized core less)
    flake.packages."less/dev"

    # Allow Ghostty to work
    ghostty.terminfo

    # Http stuff
    wget curl
    # Misc utils
    ripgrep fd tree jq tmux git openssl htop lsof
    dig netcat nmap fzf direnv eza

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
  environment.sessionVariables.EDITOR = "vim";

  # Users may only be specified via nix
  users.mutableUsers = false;
  # Disable root login entirely
  users.users.root.hashedPassword = "!";
  # Create mmazzanti user
  users.users.mmazzanti = {
    isNormalUser = true;
    extraGroups = ["wheel"];
  };

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

  # Let the admin push locally-built (unsigned) closures over `nix copy` -- a
  # trusted user's imports skip signature checking. mmazzanti is already wheel
  # -> root here, so this grants no privilege they lack. Enables `just remote
  # deploy`: build locally, copy the closure, then rebuild from the checkout.
  nix.settings.trusted-users = ["mmazzanti"];

  # State version for all systems
  system.stateVersion = "25.05";
}
