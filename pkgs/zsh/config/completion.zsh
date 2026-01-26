local dumpfile="$XDG_CACHE_HOME/zsh/zcompdump"
mkdir -p "${dumpfile:h}"
autoload -Uz compinit && compinit -C -d "$dumpfile"
autoload -Uz bashcompinit && bashcompinit -d "$dumpfile"


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
