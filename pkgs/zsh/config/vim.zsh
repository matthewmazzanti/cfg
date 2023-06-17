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
