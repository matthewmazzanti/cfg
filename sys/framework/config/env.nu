use ./lib.nu [build-path-converter sh-env convert-env]

$env.ENV_CONVERSIONS = do {
  let path = build-path-converter (char esep)

  {
    PATH: $path,
    LIBEXEC_PATH: $path,
    XDG_DATA_DIRS: $path,
    XDG_CONFIG_DIRS: $path,
    XCURSOR_PATH: $path,
    INFOPATH: $path,
    GTK_PATH: $path,
    QTWEBKIT_PLUGIN_PATH: $path,
    TERMINFO_DIRS: $path,
    NIX_PATH: $path,
    NIX_PROFILES: (build-path-converter ' ')
    GIO_EXTRA_MODULES: $path,
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
