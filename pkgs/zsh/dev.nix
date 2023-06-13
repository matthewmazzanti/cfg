{ pkgs
, stdenv
, callPackage
, zsh
, zsh-fast-syntax-highlighting
, zsh-autosuggestions
}:
let
  wrapZsh = callPackage ./wrapper.nix { };

  fshPlugin = ''${zsh-fast-syntax-highlighting}/share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh'';
  fshTheme = stdenv.mkDerivation {
    name = "fsh-theme";
    nativeBuildInputs = [ zsh ];
    buildCommand = ''
      zsh << EOF
        source "${fshPlugin}"
        FAST_WORK_DIR="$out"
        mkdir -p "$out"
        fast-theme "${./config/fsh-colors.ini}"
      EOF
    '';
  };

  zshrc = ''
    HELPDIR="${zsh}/share/zsh/$ZSH_VERSION/help"

    # Tell zsh how to find installed completions.
    for p in ''${(z)NIX_PROFILES}; do
      fpath=(
        $p/share/zsh/site-functions
        $p/share/zsh/$ZSH_VERSION/functions
        $p/share/zsh/vendor-completions
        $fpath
      )
    done

    autoload -U compinit && compinit
    autoload -U bashcompinit && bashcompinit

    # Fast Syntax Highlighting
    FAST_WORK_DIR="${fshTheme}"
    source "${fshPlugin}"
    # Man highlighting takes a huge amount of time, skip
    FAST_HIGHLIGHT[chroma-man]=

    # Zsh Autosuggestions
    source "${zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_USE_ASYNC=true
    ZSH_AUTOSUGGEST_HISTORY_IGNORE="cd *"

    eval "$(direnv hook zsh)"
    source "$(fzf-share)/key-bindings.zsh"
    source ${./config/copy.zsh}
    source ${./config/vim.zsh}
    source ${./config/prompt.zsh}
    source ${./config/history.zsh}
    source ${./config/ls.zsh}
    source ${./config/tar.zsh}
  '';
in
wrapZsh {
  inherit zsh zshrc;
}
