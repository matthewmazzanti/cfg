{ pkgs, lib, config, ... }:
with lib;
let
  font = config.theme.font;
  color = config.theme.color;
  short-pwd = pkgs.callPackage ./scripts/short-pwd {};
  xdg = config.home.xdg;

  pager = pkgs.writeShellScript "pg" ''
    ${pkgs.less}/bin/less \
      --chop-long-lines \
      --RAW-CONTROL-CHARS \
      --quit-if-one-screen \
      --mouse \
      --wheel-lines 5 \
      --ignore-case \
      --prompt=%lb/%L \
      $@
  '';
in
{
  options = {
    theme = mkOption {
      type = types.attrs;
    };
  };

  config = {
    home = {
      packages = with pkgs; [
        short-pwd
        imagemagick
      ];
      file = {
        ".config/fsh/overlay.ini".source = ./fsh-colors.ini;
      };
    };

    programs.zsh = {
      enable = true;
      defaultKeymap = "viins";
      enableAutosuggestions = true;
      # Disable to use fast-syntax-highlighting
      enableCompletion = false;
      history.share = false;

      plugins = with pkgs; [
        {
          name = "fast-syntax-highlighting";
          src = "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/site-functions";
        }
      ];

      sessionVariables = {
        # Make ls directories not bold
        LS_COLORS = "di=0;34";

        # Less/paging
        # TODO: make this a script
        PAGER = "${pager}";
        BAT_PAGER = "${pager}";
        SYSTEMD_PAGER = "${pager}";
        SYSTEMD_LESS = "-SRF";
        MANPAGER = "sh -c 'col -bx | bat -l man -p'";
        MANLESS="";
        GIT_PAGER = "${pager}";
        LESS="";
        LESSHIST = "${xdg.dirs.history}/less";

        GPG_TTY = "$(tty)";

        FZF_CTRL_T_COMMAND = "rg --files --hidden --glob='!*.git/*'";

        # https://github.com/zdharma/fast-syntax-highlighting/issues/185
        # Looks like a "won't fix"
        FAST_WORK_DIR = "${xdg.dirs.cache}/fsh";
      };

      shellAliases = {
        grep="grep --color=auto";
        egrep="egrep --color=auto";
        fgrep="fgrep --color=auto";

        ls = "ls --color=auto --group-directories-first";
        ll = "ls -l";
        la = "ls -la";
        tree = "tree --dirsfirst";

        untar = "tar -xzvf";
        lstar = "tar -tzvf";
        ".." = "cd ..";

        pg = "${pager}";
        less = "${pager}";
        cat = "bat";
        icat = "kitty +kitten icat";
        mail = "neomutt";

        open = "xdg-open";
        userctl = "systemctl --user";
        userlog = "journalctl --user";
      };

      initExtraBeforeCompInit = ''
        if [ "$TERM" = "linux" ]; then
          echo "\e]P0${color.bg}"
          echo "\e]P1${color.red}"
          echo "\e]P2${color.green}"
          echo "\e]P3${color.yellow}"
          echo "\e]P4${color.blue}"
          echo "\e]P5${color.purple}"
          echo "\e]P6${color.cyan}"
          echo "\e]P7${color.fg}"
          echo "\e]P8${color.bright.bg}"
          echo "\e]P9${color.bright.red}"
          echo "\e]Pa${color.bright.green}"
          echo "\e]Pb${color.bright.yellow}"
          echo "\e]Pc${color.bright.blue}"
          echo "\e]Pd${color.bright.purple}"
          echo "\e]Pe${color.bright.cyan}"
          echo "\e]Pf${color.bright.fg}"
          clear
        fi

        # Hook vi-mode yanks into global copy/paste buffer
        function clip-wrap-widgets() {
            local copy_or_paste=$1
            shift

            for widget in $@; do
                if [[ $copy_or_paste == "copy" ]]; then
                    eval "
                    function _clip-wrapped-$widget() {
                        zle .$widget
                        print -rn -- \$CUTBUFFER | ${pkgs.xsel}/bin/xsel -i -b -p;
                    }
                    "
                else
                    eval "
                    function _clip-wrapped-$widget() {
                        CUTBUFFER=\$(${pkgs.xsel}/bin/xsel -o -b -p </dev/null)
                        zle .$widget
                    }
                    "
                fi

                zle -N "clip-$widget" "_clip-wrapped-$widget"
            done
        }

        local copy_widgets=(
            vi-yank
            vi-yank-eol
            vi-change
            vi-change-eol
            vi-change-whole-line
            vi-delete
            vi-kill-eol
        )
        local paste_widgets=(
            vi-put-{before,after}
            put-replace-selection
        )

        clip-wrap-widgets copy $copy_widgets
        clip-wrap-widgets paste  $paste_widgets
      '';

      initExtra = ''
        # Stay dry
        setopt hist_ignore_all_dups
        setopt hist_find_no_dups
        setopt hist_reduce_blanks
        setopt share_history
        setopt inc_append_history

        # Faster escapes (10ms)
        export KEYTIMEOUT=1

        # Remove key conflicts
        bindkey -M vicmd '^[' undefined-key
        bindkey -rpM vicmd '^['

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

        # Setup prompt
        ${builtins.readFile ./prompt.zsh}

        gpg-connect-agent updatestartuptty /bye > /dev/null

        # Fast Syntax Highlighting
        # Disable man hightlighting, doesnt seem to work
        FAST_HIGHLIGHT[chroma-man]=

        # Enable custom theme for fast-syntax-highlighting
        fast-theme XDG:overlay &> /dev/null

        # Zsh Autosuggestions
        ZSH_AUTOSUGGEST_STRATEGY=(history completion)
        ZSH_AUTOSUGGEST_USE_ASYNC=true
        ZSH_AUTOSUGGEST_HISTORY_IGNORE="cd *"

        ${builtins.readFile ./fzf.zsh}

        ${builtins.readFile ./functions.zsh}
      '';
    };
  };
}
