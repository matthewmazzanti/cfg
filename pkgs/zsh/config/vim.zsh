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
