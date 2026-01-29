# Direnv Integration
() {
    (( $+commands[direnv] )) && eval "$(direnv hook zsh)"
}

# Ghostty Integration
() {
    [[ -n ${GHOSTTY_RESOURCES_DIR-} ]] || return

    # Remove "cursor" from GHOSTTY_SHELL_FEATURES if present
    if [[ -n ${GHOSTTY_SHELL_FEATURES-} ]]; then
        local -a ghostty_features
        ghostty_features=(${(s:,:)GHOSTTY_SHELL_FEATURES})
        ghostty_features=(${ghostty_features:#cursor})
        GHOSTTY_SHELL_FEATURES=${(j:,:)ghostty_features}
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
