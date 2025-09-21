use ./lib.nu [build-path-converter sh-env convert-env]

$env.ENV_CONVERSIONS = do {
  let path = build-path-converter (char esep)

  {
    # -------------------------
    # GNOME / GTK / GStreamer stack
    # -------------------------
    GIO_EXTRA_MODULES: $path,          # GNOME I/O extensions (gvfs, etc.)
    GI_TYPELIB_PATH: $path,            # GObject Introspection typelib search path
    GST_PLUGIN_SYSTEM_PATH_1_0: $path, # GStreamer plugin search path
    GTK_PATH: $path,                   # Extra GTK module search path (themes, engines, etc.)
    XCURSOR_PATH: $path,               # Cursor themes (affects Wayland compositors too),

    # -------------------------
    # Qt
    # -------------------------
    QTWEBKIT_PLUGIN_PATH: $path,       # Legacy QtWebKit plugins; rarely used on modern Wayland setups,

    # -------------------------
    # XDG Base Directories
    # -------------------------
    XDG_CONFIG_DIRS: $path,            # System-wide config dirs (e.g. `/etc/xdg`, Nix profile paths)
    XDG_DATA_DIRS: $path,              # System-wide data dirs (icons, .desktop files, schemas, etc.),

    # -------------------------
    # Terminal / Shell environment
    # -------------------------
    INFOPATH: $path,                   # GNU info docs (from Nix profiles)
    LIBEXEC_PATH: $path,               # Aux executables (`libexec` bins from packages)
    # LS_COLORS: $path,                  # Color scheme for `ls --color`
    TERMINFO_DIRS: $path,              # ncurses/terminfo databases (needed for tmux, alacritty, etc.),

    # -------------------------
    # Nix-specific
    # -------------------------
    NIX_PATH: $path,                   # Nixpkgs channels, flakes fallback
    NIX_PROFILES: (build-path-converter ' '), # Active Nix profiles (stacked, e.g. user + system),

    # -------------------------
    # General system session
    # -------------------------
    PATH: $path,                       # Executable search path (composed from Nix profiles + system)
    SESSION_MANAGER: $path,            # Mostly an X11 legacy var; not used in pure Wayland sessions,
    LS_COLORS: {
      from_string: {|value|
        $value
        | split row ':'
        | parse '{key}={value}'
        | each {|row|
          { $row.key: ($row.value | split row ';') }
        }
        | into record
      },
      to_string: {|value|
        $value
        | items {|key value|
          $"($key)=($value | str join ';')"
        }
        | str join ':'
      }
    }
  }
}

# Ensure PATH exists in Nushell (as an empty list if undefined) to prevent errors
if ($env.PATH? | is-empty) {
  $env.PATH = []
}

[ /etc/profile, ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]
| where {|path| $path | path exists }
| sh-env
| convert-env
| load-env
