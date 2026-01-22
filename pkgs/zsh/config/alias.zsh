() {
    local is_darwin=0
    [[ "$(uname -s)" == Darwin ]] && is_darwin=1

    # Colors: set LS_COLORS if possible (only if not already set)
    if [[ -z ${LS_COLORS-} ]]; then
        # Homebrew
        if (( is_darwin && $+commands[gdircolors] )); then
            eval "$(gdircolors -b 2>/dev/null)"
        elif (( $+commands[dircolors] )); then
            eval "$(dircolors -b 2>/dev/null)"
        fi
    fi

    # ls: prefer eza, then gls (Darwin only), then GNU ls, then BSD fallback
    if (( $+commands[eza] )); then
        alias ls='eza --color=auto --group-directories-first --classify'
    # Homebrew
    elif (( is_darwin && $+commands[gls] )); then
        alias ls='gls --color=auto --group-directories-first --classify --dereference-command-line'
    elif (( is_darwin )); then
        alias ls='ls -G -F'
    else
        alias ls='ls --color=auto --group-directories-first --classify --dereference-command-line'
    fi

    # tree: only alias if an implementation exists
    if (( $+commands[eza] )); then
        alias tree='eza --tree --group-directories-first'
    elif (( $+commands[tree] )); then
        alias tree='tree --dirsfirst'
    fi

    function mktar() {
      local target=$1
      [[ -z $target ]] && return 1
      tar -czvf "${target:t}.tar.gz" "$target"
    }
    alias untar="tar -xzvf"
    alias lstar="tar -tzvf"
}
