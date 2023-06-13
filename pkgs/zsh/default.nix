{
  # Core nixpkgs imports
  pkgs
, lib
, stdenv
, # Derivation utils
  makeWrapper
, writeTextFile
, symlinkJoin
, nvim
, less
}:
let
  config = {
    package = pkgs.zsh;
    compinit = true;
    bashcompinit = true;
    path = [
      "/opt/homebrew/bin"
    ];
    packages = with pkgs; [
      nvim
      less

      coreutils
      vim
      curl
      wget
      git

      ripgrep
      fd
      bat
      tree
      direnv
      fzf
      jq
      httpie
    ];

    zshrc = ''
      eval "$(direnv hook zsh)"
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${./src/copy.zsh}
      source ${./src/prompt.zsh}

      # History options
      SAVEHIST=2000
      HISTSIZE=2000
      HISTFILE=$HOME/.zsh_history
      setopt HIST_IGNORE_DUPS SHARE_HISTORY HIST_FCNTL_LOCK
      setopt hist_ignore_all_dups
      setopt hist_find_no_dups
      setopt hist_reduce_blanks
      setopt share_history
      setopt inc_append_history


      # Bracketed paste
      printf "\e[?2004h"

      # Vi mode
      bindkey -v
      # Faster escapes (10ms)
      KEYTIMEOUT=1
      # Vim backspacing
      bindkey -v '^?' backward-delete-char
      # Copy paste improvements
      bindkey -M vicmd 'y' clip-vi-yank
      bindkey -M vicmd 'Y' clip-vi-yank-eol
      bindkey -M vicmd 'x' clip-vi-delete
      bindkey -M visual 'x' clip-vi-delete
      bindkey -M vicmd 'X' clip-vi-kill-eol
      bindkey -M vicmd 'p' clip-vi-put-after
      bindkey -M vicmd 'P' clip-vi-put-before
      bindkey -M visual 'p' clip-put-replace-selection


      # Setup ls and tree to be a little nicer
      eval "export $(dircolors | sed 's/01;/0;/g')"
      alias ls="ls --color=auto --group-directories-first --classify --dereference-command-line"
      alias tree="tree --dirsfirst"


      # Tar aliases/functions since I always forget
      function mktar() {
        tar -czvf "$(basename $1).tar.gz" "$1"
      }
      alias untar="tar -xzvf"
      alias lstar="tar -tzvf"

      alias vim=nvim
      alias vi=vim
      export EDITOR=nvim

      function init() {(
        set -e
        template="$1"
        dest="$2"

        # Copy template
        nix flake new --template "$HOME/src/nix/templates#$template" "$dest"
        cd "$dest"

        # Initialize git repo
        git init
        git add .
        git commit -m "Initial commit from template $template"

        # Update flake, commit
        nix flake update \
          --commit-lock-file \
          --commit-lockfile-summary "Update flake.lock"
      )}
    '';

    plugins.fast-syntax-highlighting = {
      enable = true;
      theme = ./src/fsh-colors.ini;
      package = pkgs.zsh-fast-syntax-highlighting;
      extraConfig = ''
        # Fast Syntax Highlighting
        # Man highlighting takes a huge amount of time
        FAST_HIGHLIGHT[chroma-man]=
      '';
    };

    plugins.autosuggestions = {
      enable = true;
      package = pkgs.zsh-autosuggestions;
      extraConfig = ''
        # Zsh Autosuggestions
        ZSH_AUTOSUGGEST_STRATEGY=(history completion)
        ZSH_AUTOSUGGEST_USE_ASYNC=true
        ZSH_AUTOSUGGEST_HISTORY_IGNORE="cd *"
      '';
    };
  };


  syntax-highlighting =
    let
      cfg = config.plugins.fast-syntax-highlighting;

      # TODO: Cache the default theme
      theme = stdenv.mkDerivation {
        name = "fast-work-dir";
        nativeBuildInputs = with pkgs; [ zsh cfg.package ];
        buildCommand = ''
          zsh << EOF
            source ${cfg.package}/share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh
            FAST_WORK_DIR="$out"
            mkdir -p "$out"
            fast-theme "${cfg.theme}"
          EOF
        '';
      };
    in
    ''
      FAST_WORK_DIR="${theme}"
      source ${cfg.package}/share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh
      ${cfg.extraConfig}
    '';

  autosuggestions =
    let cfg = config.plugins.autosuggestions;
    in ''
      source ${cfg.package}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
      ${cfg.extraConfig}
    '';

  path = lib.concatStringsSep ":" config.path;
  packagesPath = symlinkJoin {
    name = "packagesPath";
    paths = config.packages;
  };

  # https://superuser.com/a/648046
  # zsh's default handling for escape sequences is not great for a vi mode.
  # By default, it will wait KEYTIMEOUT deciseconds (yeah..) after the last input if the input
  # given is a prefix. If the input is a full command, this will run the command.
  #
  # However, this causes issues with terminal handling of the ESC key - which is expected to
  # start multi character sequences.
  #
  # The ideal is a long timeout for multi character sequences, but a short one for just the
  # escape key. vim seems to handle this properly, zsh seems to not have bothered.
  # bindkey -M vicmd '^[' undefined-key
  # bindkey -rpM vicmd '^['
  # bindkey -rpM viins '^['
  zshrc = ''
    export PATH="${packagesPath}/bin:${path}:$PATH"
    HELPDIR="${config.package}/share/zsh/$ZSH_VERSION/help"

    # Tell zsh how to find installed completions
    local nix_paths=($NIX_PROFILES "${packagesPath}")
    for p in ''${(z)nix_paths}; do
      fpath=(
        $p/share/zsh/site-functions
        $p/share/zsh/$ZSH_VERSION/functions
        $p/share/zsh/vendor-completions
        $fpath
      )
    done

    ${if config.compinit
      then "autoload -U compinit && compinit"
      else ""}
    ${if config.bashcompinit
      then "autoload -U bashcompinit && bashcompinit"
      else ""}

    ${autosuggestions}
    ${syntax-highlighting}
    ${config.zshrc}
  '';

  zdotdir = stdenv.mkDerivation {
    name = "zdotdir";
    inherit zshrc;
    passAsFile = [ "zshrc" ];
    buildCommand = ''
      mkdir -p "$out"
      cp "$zshrcPath" "$out/.zshrc"
    '';
  };
in
symlinkJoin {
  name = "zsh-flake";
  paths = [ config.package ];
  buildInputs = [ makeWrapper ];
  # --add-flags '--no-globalrcs' \
  postBuild = ''
    mv "$out/bin/zsh" "$out/bin/zsh-unwrapped"
    makeWrapper \
      "$out/bin/zsh-unwrapped" \
      "$out/bin/zsh" \
      --set NOSYSZSHRC "1" \
      --set ZDOTDIR "${zdotdir}"
  '';
}
