{ pkgs, flake, ... }:
let
  # Custom Zsh package produced by this flake.
  # Exposes `passthru.shellPath` so NixOS can treat it as a valid login shell.
  zshDev = flake.packages."zsh/dev";
  zshExePath = "/etc/profiles/per-user/mmazzanti${zshDev.shellPath}";
in {
  # --- Zsh defaults ---

  # Enable NixOS Zsh integration and avoid module assertions when selecting Zsh
  # as a login shell.
  programs.zsh.enable = true;

  # System-wide default shell for users without an explicit override.
  users.defaultUserShell = pkgs.zsh;

  # --- Login shell registration ---

  # Populate /etc/shells so PAM (gdm, fprintd, pam_shells, etc.) accepts the
  # shell. Omitting this will prevent login when using zshDev.
  environment.shells = [ zshExePath ];

  users.users.mmazzanti = {
    # Use the custom flake-built Zsh as the login shell.
    #
    # This uses the indirection provided by `shellPath` instead of hard-coding a
    # /nix/store path. This plays better with terminals that cache shell
    # metadata across sessions.
    shell = zshExePath;

    # Install the same shell in the user profile for explicit invocation and
    # version pinning.
    packages = [ zshDev ];
  };
}
