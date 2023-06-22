{ stdenvNoCC
, callPackage
, zsh
, zsh-fast-syntax-highlighting
, zsh-autosuggestions
}:
let
  wrapZsh = callPackage ./wrapper.nix { };

  fshPlugin = ''${zsh-fast-syntax-highlighting}/share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh'';
  fshTheme = stdenvNoCC.mkDerivation {
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
    function () {
      local count=1
      local before="/usr/local/bin"
      local brew_prefix="/opt/homebrew"

      # Add brew prefix before system, after nix
      for seg in "''${path[@]}"; do
        if [ "$seg" = "$before" ]; then
          path[$count]=("$brew_prefix/bin" "$before")
          break
        fi
        ((count++))
      done

      fpath+=("$brew_prefix/share/zsh/site-functions")
    }

    function () {
      local cachedir="$HOME/.cache/zsh"
      local dumpfile="$cachedir/zcompdump"

      if [ ! -d "$cachedir" ]; then
        mkdir -p "$cachedir"
      fi

      autoload -Uz compinit && compinit -C -d "$dumpfile"
      autoload -Uz bashcompinit && bashcompinit -d "$dumpfile"
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
