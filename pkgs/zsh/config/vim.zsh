() {
    # Vi mode
    bindkey -v

    # Faster escapes (10ms)
    KEYTIMEOUT=1

    # Vim backspacing
    bindkey -v '^?' backward-delete-char

    # Bracketed paste
    # Not sure if this does what I want exactly
    printf "\e[?2004h"

    # Use Neovim for git commits etc
    export EDITOR=nvim

    # Copy paste improvements
    bindkey -M vicmd 'y' clip-vi-yank
    bindkey -M vicmd 'Y' clip-vi-yank-eol
    bindkey -M vicmd 'x' clip-vi-delete
    bindkey -M visual 'x' clip-vi-delete
    bindkey -M vicmd 'X' clip-vi-kill-eol
    bindkey -M vicmd 'p' clip-vi-put-after
    bindkey -M vicmd 'P' clip-vi-put-before
    bindkey -M visual 'p' clip-put-replace-selection

    # Sacrilege: Emacs-style Ctrl bindings in vi command/insert modes
    for map in vicmd viins; do
        # Movement
        bindkey -M $map '^A' beginning-of-line
        bindkey -M $map '^E' end-of-line
        bindkey -M $map '^F' forward-char
        bindkey -M $map '^B' backward-char
        bindkey -M $map '^P' up-line-or-history
        bindkey -M $map '^N' down-line-or-history

        # Editing / killing
        bindkey -M $map '^K' kill-line
        bindkey -M $map '^U' backward-kill-line
        bindkey -M $map '^W' backward-kill-word
        bindkey -M $map '^Y' yank
    done
}
