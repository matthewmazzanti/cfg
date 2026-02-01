{
  stdenvNoCC,
  callPackage,
  zsh,
  zsh-fast-syntax-highlighting,
  zsh-autosuggestions,
  lib,
}: let
  wrapZsh = callPackage ./wrapper.nix {};

  autosuggestPlugin = "${zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh";

  fsh = zsh-fast-syntax-highlighting.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      # Make the "not writable" test always false so it never overrides
      # FAST_WORK_DIR
      substituteInPlace fast-syntax-highlighting.plugin.zsh \
        --replace 'if [[ ! -w $FAST_WORK_DIR ]]; then' 'if false; then'
    '';
  });
  fshPlugin = "${fsh}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh";
  fshTheme = stdenvNoCC.mkDerivation {
    name = "fsh-theme";
    nativeBuildInputs = [zsh];
    buildCommand = ''
      zsh << EOF
        FAST_WORK_DIR="$out"
        mkdir -p "$out"
        source "${fshPlugin}"
        fast-theme "${./config/fsh-colors.ini}"
      EOF
    '';
  };

  zshenv = ''
    setopt no_global_rcs
  '';

  # TODO: Work through better ordering for all this
  # Layered zle widgets make this hard to do "right", and I'm not 100% clear on
  # desired wrappings myself at this point
  zshrc = ''
    typeset -gA NIX_INPUTS=(
        fsh_theme   ${lib.escapeShellArg fshTheme}
        fsh_plugin  ${lib.escapeShellArg fshPlugin}
        autosuggest ${lib.escapeShellArg autosuggestPlugin}
    )
    source_scoped() { source "$1" }

    source_scoped ${lib.escapeShellArg "${./config/base-env.zsh}"}
    source_scoped ${lib.escapeShellArg "${./config/completion.zsh}"}
    source_scoped ${lib.escapeShellArg "${./config/plugins.zsh}"}
    source_scoped ${lib.escapeShellArg "${./config/lib.zsh}"}
    source_scoped ${lib.escapeShellArg "${./config/fzf.zsh}"}
    source_scoped ${lib.escapeShellArg "${./config/clip.zsh}"}
    source_scoped ${lib.escapeShellArg "${./config/prompt.zsh}"}
    source_scoped ${lib.escapeShellArg "${./config/init.zsh}"}
    unset NIX_INPUTS
  '';
in
  wrapZsh {
    inherit zsh zshrc zshenv;
  }
