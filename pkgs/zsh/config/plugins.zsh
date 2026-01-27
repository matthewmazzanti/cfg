# Direnv Integration
() {
    (( $+commands[direnv] )) && eval "$(direnv hook zsh)"
}

# Fzf
() {
    (( $+commands[fzf] && $+commands[fzf-share] && $+commands[fd] )) || return

    local -a fd_opts=(
        "--hidden"
        "--ignore"
        "--no-follow"
        "--exclude" ".git/"
        "--strip-cwd-prefix"
    )

    export FZF_DEFAULT_OPTS="--reverse"
    export FZF_DEFAULT_COMMAND="fd --type f $fd_opts"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    # export FZF_CTRL_T_OPTS=""
    export FZF_CTRL_R_OPTS="--reverse"
    export FZF_ALT_C_COMMAND="fd --type d $fd_opts"
    # export FZF_ALT_C_OPTS=""

    source "$(fzf-share)/key-bindings.zsh"
}

# Ghostty Integration
() {
    [[ -n ${GHOSTTY_RESOURCES_DIR-} ]] || return

    # Remove "cursor" from GHOSTTY_SHELL_FEATURES if present
    if [[ -n ${GHOSTTY_SHELL_FEATURES-} ]]; then
        local -a ghostty_features
        ghostty_features=(${(s:,:)GHOSTTY_SHELL_FEATURES})
        ghostty_features=(${_ghostty_features:#cursor})
        GHOSTTY_SHELL_FEATURES=${(j:,:)_ghostty_features}
    fi

    local file="$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
    [[ -f $file ]] || return

    source "$file"
}

# Fast Syntax Highlighting
() {
    FAST_WORK_DIR="${NIX_INPUTS[fsh_theme]}"
    source "${NIX_INPUTS[fsh_plugin]}"
    # Man highlighting takes a huge amount of time, skip
    FAST_HIGHLIGHT[chroma-man]=
}

# Zsh Autosuggestions
() {
    source "${NIX_INPUTS[autosuggest]}"
    # God I hate zsh
    # For some reason, autosuggestions does this late init thing. I want it
    # _under_ my copy wrapper, so unset their precmd hook (which default ALWAYS
    # RUNS, insane) and set up ourselves
    add-zsh-hook -d precmd _zsh_autosuggest_start
    _zsh_autosuggest_start
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_USE_ASYNC=true
    ZSH_AUTOSUGGEST_HISTORY_IGNORE="cd *"
}
