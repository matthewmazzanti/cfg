# --- Platform Detection ---

local is_darwin=0
[[ "$(uname -s)" == Darwin ]] && is_darwin=1


# --- History Settings ---
SAVEHIST=10000
HISTSIZE=10000
HISTFILE="$XDG_STATE_HOME/zsh/history"
mkdir -p "${HISTFILE:h}"

setopt share_history
setopt inc_append_history
setopt hist_ignore_dups
setopt hist_ignore_all_dups
setopt hist_find_no_dups
setopt hist_fcntl_lock
setopt hist_reduce_blanks


# --- Vim Config ---

# Enable Vi mode
bindkey -v

# Faster escape from insert → command (10ms)
KEYTIMEOUT=1

# Vim-style backspace
bindkey -v '^?' backward-delete-char

# Enable bracketed paste
# (Allows shells/editors to detect pasted text)
printf '\e[?2004h'

# Copy/paste improvements
bindkey -M vicmd  'x' vi-delete
bindkey -M visual 'x' vi-delete
bindkey -M vicmd  'X' vi-kill-eol
# Blackhole "d" emulation
bindkey -M vicmd  'd' _clip_orig__vi-delete
bindkey -M visual 'd' _clip_orig__vi-delete
bindkey -M vicmd  'D' _clip_orig__vi-kill-eol

# Sacrilege: Emacs-style Ctrl bindings in vi command/insert modes
for map in vicmd viins; do
    # Movement
    bindkey -M "$map" '^A' beginning-of-line
    bindkey -M "$map" '^E' end-of-line
    bindkey -M "$map" '^F' forward-char
    bindkey -M "$map" '^B' backward-char
    bindkey -M "$map" '^P' up-line-or-history
    bindkey -M "$map" '^N' down-line-or-history
done

# Editing / killing
bindkey -M viins '^K' kill-line
bindkey -M viins '^U' backward-kill-line
bindkey -M viins '^Y' yank
bindkey -M viins '^[^?' backward-kill-word
bindkey -M viins '^[\b' backward-kill-word
bindkey -M viins '^H' backward-kill-word

# --- Aliases & Variables ---

# Initialize LS_COLORS if unset
if [[ -z ${LS_COLORS-} ]]; then
    if (( is_darwin && $+commands[gdircolors] )); then
        eval "$(gdircolors -b 2>/dev/null)"
    elif (( $+commands[dircolors] )); then
        eval "$(dircolors -b 2>/dev/null)"
    fi
fi


# ls
local ls_opts=(
    --color=auto
    --group-directories-first
    --classify
)
if (( $+commands[eza] )); then
    alias ls="eza $ls_opts"
    compdef eza=ls
elif (( is_darwin && $+commands[gls] )); then
    alias ls="gls $ls_opts --dereference-command-line"
elif (( is_darwin )); then
    alias ls='ls -G -F'
else
    alias ls="ls $ls_opts --dereference-command-line"
fi


# tree
if (( $+commands[eza] )); then
    alias tree="eza $ls_opts --tree"
    compdef eza=tree
elif (( $+commands[tree] )); then
    alias tree='tree --dirsfirst'
fi


# tar helpers
alias untar='tar -xzvf'
alias lstar='tar -tzvf'
function mktar() {
    local target=$1
    [[ -z $target ]] && return 1
    tar -czvf "${target:t}.tar.gz" "$target"
}


# Default editor
export EDITOR=nvim


# Path shortcuts
cfg="$HOME/src/nix/cfg"
[[ -d $cfg ]] || unset cfg

notes="$HOME/Documents/Notes"
[[ -d $notes ]] || unset notes


# --- Local Overrides ---
local zshrc_local="$XDG_CONFIG_HOME/zsh/zshrc"
[[ -f $zshrc_local ]] && source "$zshrc_local"
