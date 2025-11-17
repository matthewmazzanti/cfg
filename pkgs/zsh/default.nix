{
  stdenvNoCC,
  callPackage,
  zsh,
  zsh-fast-syntax-highlighting,
  zsh-autosuggestions,
}: let
  wrapZsh = callPackage ./wrapper.nix {};

  fsh = zsh-fast-syntax-highlighting.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      # Make the "not writable" test always false so it never overrides
      # FAST_WORK_DIR
      substituteInPlace fast-syntax-highlighting.plugin.zsh \
        --replace 'if [[ ! -w $FAST_WORK_DIR ]]; then' 'if false; then'
    '';
  });
  fshPlugin = "${fsh}/share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh";
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

  zshrc = ''
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    if command -v direnv &> /dev/null; then
        eval "$(direnv hook zsh)"
    fi

    () {
        local cachedir="$HOME/.cache/zsh"
        local dumpfile="$cachedir/zcompdump"

        if [ ! -d "$cachedir" ]; then
          mkdir -p "$cachedir"
        fi

        autoload -Uz compinit && compinit -C -d "$dumpfile"
        autoload -Uz bashcompinit && bashcompinit -d "$dumpfile"
    }

    () {
        [[ -n "$GHOSTTY_RESOURCES_DIR" ]] || return
        local file="$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
        [[ -f "$file" ]] || return
        source "$file"
    }

    # Zsh completion has this dumb thing where it will SSH into remote servers
    # to suggest file paths. With autosuggestions, this causes an SSH
    # connection to occur for each keypress causing a number of undesirable
    # effects:
    # - Overloading the remote server and causing you to get timed out
    # - Mangling the prompt, if a TUI password request gets rendered
    # - Repeatedly popping up an SSH passphrase prompt and forcing you to lose
    # focus on your terminal if a GUI askpass is setup
    #
    # All of this is dumb, and honestly a terrible idea. Disable remote-access
    # to fix
    zstyle ':completion:*' remote-access no

    # Source before highlighting for correct updates. Keybindings defined in
    # "vim.zsh"
    source ${./config/copy.zsh}

    # Fast Syntax Highlighting
    FAST_WORK_DIR='${fshTheme}'
    source '${fshPlugin}'
    # Man highlighting takes a huge amount of time, skip
    FAST_HIGHLIGHT[chroma-man]=

    # Zsh Autosuggestions
    source '${zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh'
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_USE_ASYNC=true
    ZSH_AUTOSUGGEST_HISTORY_IGNORE="cd *"

    source "${./config/vim.zsh}"
    source "${./config/prompt.zsh}"
    source "${./config/history.zsh}"
    source "${./config/ls.zsh}"
    source "${./config/tar.zsh}"
    source "${./config/fzf.zsh}"

    cfg="$HOME/src/nix/cfg"

    if [[ -f "$HOME/.zshrc" ]]; then
        source "$HOME/.zshrc"
    fi
  '';
in
  wrapZsh {
    inherit zsh zshrc;
  }
