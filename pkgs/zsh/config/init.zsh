# --- Platform Detection ---
local is_darwin=0
[[ "$(uname -s)" == Darwin ]] && is_darwin=1

# --- History Settings ---
SAVEHIST=10000
HISTSIZE=10000
HISTFILE="$XDG_STATE_HOME/zsh/history"
mkdir -p "${HISTFILE:h}"

setopt extended_history
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
# Faster escape from insert -> command (10ms)
KEYTIMEOUT=1
# Vim-style backspace
bindkey -v '^?' backward-delete-char

# Enable bracketed paste
# (Allows shells/editors to detect pasted text)
printf '\e[?2004h'

# c / C - change -> blackhole
bindkey -M vicmd  'c' "$(clip_widget blackhole vi-change)"
bindkey -M visual 'c' "$(clip_widget blackhole vi-change)"
bindkey -M vicmd  'C' "$(clip_widget blackhole vi-change-eol)"

# s / S - substitute -> blackhole
bindkey -M vicmd  's' "$(clip_widget blackhole vi-substitute)"
bindkey -M visual 's' "$(clip_widget blackhole vi-substitute)"
bindkey -M vicmd  'S' "$(clip_widget blackhole vi-change-whole-line)"

# d / D - delete -> blackhole
bindkey -M vicmd  'd' "$(clip_widget blackhole vi-delete)"
bindkey -M visual 'd' "$(clip_widget blackhole vi-delete)"
bindkey -M vicmd  'D' "$(clip_widget blackhole vi-kill-eol)"

# x / X - "cut" -> system copy (Custom mapping)
bindkey -M vicmd  'x' "$(clip_widget copy vi-delete)"
bindkey -M visual 'x' "$(clip_widget copy vi-delete)"
bindkey -M vicmd  'X' "$(clip_widget copy vi-kill-eol)"

# y / Y - yank -> system copy
bindkey -M vicmd  'y' "$(clip_widget copy vi-yank)"
bindkey -M visual 'y' "$(clip_widget copy vi-yank)"
bindkey -M vicmd  'Y' "$(clip_widget copy vi-yank-eol)"

# p / P - paste -> system paste
bindkey -M vicmd  'p' "$(clip_widget paste vi-put-after)"
bindkey -M visual 'p' "$(clip_widget paste put-replace-selection)"
bindkey -M vicmd  'P' "$(clip_widget paste vi-put-before)"

# Emacs-style movement (vi mode only)
for map in vicmd viins; do
  bindkey -M "$map" '^A' beginning-of-line
  bindkey -M "$map" '^E' end-of-line
  bindkey -M "$map" '^F' forward-char
  bindkey -M "$map" '^B' backward-char
  bindkey -M "$map" '^P' up-line-or-history
  bindkey -M "$map" '^N' down-line-or-history
done

# Emacs-style editing (viins only)
bindkey -M viins '^K'   "$(clip_widget blackhole kill-line)"
bindkey -M viins '^U'   "$(clip_widget blackhole backward-kill-line)"
bindkey -M viins '^[^?' "$(clip_widget blackhole backward-kill-word)"
bindkey -M viins '^[\b' "$(clip_widget blackhole backward-kill-word)"
bindkey -M viins '^H'   "$(clip_widget blackhole backward-kill-word)"

# FZF integration
bindkey -M emacs '^R' fzf-history-widget
bindkey -M vicmd '^R' fzf-history-widget
bindkey -M viins '^R' fzf-history-widget

bindkey -M emacs '\ec' fzf-cd-widget
bindkey -M viins '\ec' fzf-cd-widget
bindkey -M vicmd '\ec' fzf-cd-widget

bindkey -M emacs '^T' fzf-file-widget
bindkey -M vicmd '^T' fzf-file-widget
bindkey -M viins '^T' fzf-file-widget

# Jumplist (Neovim-style directory navigation)
bindkey -M vicmd '^O' jumplist-back-widget
bindkey -M viins '^O' jumplist-back-widget
bindkey -M vicmd '\e[105;5u' jumplist-forward-widget  # CSI u for Ctrl-I (Ghostty)
bindkey -M viins '\e[105;5u' jumplist-forward-widget
alias jl=jumplist

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
() {
    local ls_args=(
        --color=auto
        --group-directories-first
        --classify
    )
    local gnu_ls_args=(
        "${ls_opts[@]}"
        --dereference-command-line
    )
    if (( $+commands[eza] )); then
        alias ls="eza $ls_args"
        compdef eza=ls
    elif (( is_darwin )); then
        # macOS: detect best ls
        if command ls --version >/dev/null 2>&1; then
            # GNU ls (coreutils shadowing system ls)
            alias ls="ls $gnu_ls_args"

        elif (( $+commands[gls] )); then
            # Homebrew coreutils
            alias ls="gls $gnu_ls_args"

        else
            # BSD/macOS default
            alias ls='ls -G -F'
        fi
    else
        alias ls="ls $gnu_ls_args"
    fi
}


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
