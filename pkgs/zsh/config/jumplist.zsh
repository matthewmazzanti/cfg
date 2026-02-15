# Jumplist - Neovim-style directory navigation
# Ctrl-O to go back, Ctrl-I to go forward
# Uses "drop suffix on change" behavior

typeset -ga _jumplist_stack=("$PWD")
typeset -gi _jumplist_pos=1
typeset -gi _jumplist_navigating=0

function _jumplist_chpwd() {
    # Skip if we're navigating via Ctrl-O/Ctrl-I
    (( _jumplist_navigating )) && return

    # Skip if same directory (shouldn't happen but defensive)
    [[ "${_jumplist_stack[$_jumplist_pos]}" == "$PWD" ]] && return

    # Drop suffix: truncate stack after current position
    _jumplist_stack=("${_jumplist_stack[@]:0:$_jumplist_pos}")

    # Append new directory
    _jumplist_stack+=("$PWD")
    (( _jumplist_pos++ ))
}

function _jumplist_back() {
    (( _jumplist_pos <= 1 )) && return 1
    (( _jumplist_pos-- ))
    _jumplist_navigating=1
    cd "${_jumplist_stack[$_jumplist_pos]}"
    _jumplist_navigating=0
}

function _jumplist_forward() {
    (( _jumplist_pos >= ${#_jumplist_stack[@]} )) && return 1
    (( _jumplist_pos++ ))
    _jumplist_navigating=1
    cd "${_jumplist_stack[$_jumplist_pos]}"
    _jumplist_navigating=0
}

function _jumplist_reset() {
    _jumplist_stack=("$PWD")
    _jumplist_pos=1
}

function _jumplist_show() {
    local i dir
    for (( i = 1; i <= ${#_jumplist_stack[@]}; i++ )); do
        dir="${_jumplist_stack[$i]/#$HOME/~}"
        if (( i == _jumplist_pos )); then
            printf '> %s\n' "$dir"
        else
            printf '  %s\n' "$dir"
        fi
    done
}

function jumplist() {
    case "${1:-show}" in
        back)    _jumplist_back ;;
        forward) _jumplist_forward ;;
        reset)   _jumplist_reset ;;
        show)    _jumplist_show ;;
    esac
}

function jumplist-back-widget() {
    _jumplist_back
    zle reset-prompt
}

function jumplist-forward-widget() {
    _jumplist_forward
    zle reset-prompt
}

zle -N jumplist-back-widget
zle -N jumplist-forward-widget

# Register chpwd hook
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _jumplist_chpwd
