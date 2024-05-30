{
  lib,
  bashInteractive,
  system,
  writeTextFile,
}: let
  bashPath = "${bashInteractive}/bin/bash";
in
  {
    name ? "devshell",
    # A path to a script that will be loaded by the shell
    packages,
  }:
    derivation {
      inherit name system;

      # `nix develop` actually checks and uses builder. And it must be bash.
      builder = bashPath;
      args = ["-ec"];

      # $stdenv/setup is loaded by nix-shell during startup.
      # https://github.com/nixos/nix/blob/377345e26f1ac4bbc87bb21debcc52a1d03230aa/src/nix-build/nix-build.cc#L429-L432
      stdenv = writeTextFile {
        name = "naked-stdenv";
        destination = "/setup";
        text = ''
          # Fix for `nix develop`
          : ''${outputs:=out}

          runHook() {
            eval "$shellHook"
            unset runHook
          }
        '';
      };

      # The shellHook is loaded directly by `nix develop`. But nix-shell
      # requires that other trampoline.
      shellHook = ''
        # Remove all the unnecessary noise that is set by the build env
        unset NIX_BUILD_TOP NIX_BUILD_CORES NIX_BUILD_TOP NIX_STORE
        unset TEMP TEMPDIR TMP TMPDIR
        unset builder name out shellHook stdenv system
        # Flakes stuff
        unset dontAddDisableDepTrack outputs

        # For `nix develop`
        if [[ "$SHELL" == "/noshell" ]]; then
          export SHELL=${bashPath}
        fi

        # Create the path
        export PATH="${lib.makeBinPath packages}:$PATH"
      '';
    }
