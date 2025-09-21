{ runCommand
, makeWrapper
, nushell
}:

{ config }:
runCommand "nu-wrapped" {
  buildInputs = [makeWrapper];
  inherit nushell config;
  meta.mainProgram = nushell.meta.mainProgram;
} ''
  mkdir -p "$out"

  # Link all top-level entries
  while IFS= read -r -d ''' rel; do
    ln -s "$nushell/$rel" "$out/$rel"
  done < <(
    cd "$nushell"
    find . -mindepth 1 -maxdepth 1 -not -name bin -printf '%P\0'
  )

  # Replace bin symlink with a real dir
  mkdir -p "$out/bin"
  while IFS= read -r -d ''' rel; do
    ln -s "$nushell/bin/$rel" "$out/bin/$rel"
  done < <(
    cd "$nushell/bin"
    find . -mindepth 1 -maxdepth 1 -printf '%P\0'
  )

  # Build wrapper flags dynamically based on what's present in configDrv
  FLAGS=()

  cfg="$config/config.nu"
  if [ -f "$cfg" ]; then
    FLAGS+=(--add-flags "--config $cfg")
  fi

  env_cfg="$config/env.nu"
  if [ -f "$env_cfg" ]; then
    FLAGS+=(--add-flags "--env-config $env_cfg")
  fi

  plugin_cfg="$config/plugin.msgpackz"
  if [ -f "$plugin_cfg" ]; then
    FLAGS+=(--add-flags "--plugin-config $plugin_cfg")
  fi

  if [[ "''${#FLAGS[@]}" = 0 ]]; then
    echo "error: wrapper would do nothing" >&2
    exit 1
  fi

  # Create the wrapper (no shebang issues; compiled launcher)
  wrapProgram "$out/bin/nu" "''${FLAGS[@]}"
''
