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

function _jumplist_goto() {
    local target=$1
    (( target < 1 || target > ${#_jumplist_stack[@]} )) && return 1
    (( target == _jumplist_pos )) && return 0
    _jumplist_pos=$target
    _jumplist_navigating=1
    cd "${_jumplist_stack[$_jumplist_pos]}"
    _jumplist_navigating=0
}

function _jumplist_entries() {
    local i marker
    for (( i = 1; i <= ${#_jumplist_stack[@]}; i++ )); do
        (( i == _jumplist_pos )) && marker='>' || marker=' '
        printf '%s\t%s %s\0' "$i" "$marker" "${_jumplist_stack[$i]/#$HOME/~}"
    done
}

function _jumplist_pick() {
    (( ! ${+commands[fzf]} )) && return 1
    local fzf_args=(
        "${_fzf_common[@]}"
        --scheme=path
        --no-multi
        --read0
        --delimiter=$'\t'
        --with-nth=2
        --accept-nth=1
        --bind="load:pos($_jumplist_pos)"
    )
    local selected=$(_jumplist_entries | fzf "${fzf_args[@]}")
    [[ -n "$selected" ]] && _jumplist_goto "$selected"
}

function jumplist() {
    case "${1:-show}" in
        back)    _jumplist_back ;;
        forward) _jumplist_forward ;;
        reset)   _jumplist_reset ;;
        show)    _jumplist_show ;;
        goto)    _jumplist_goto "$2" ;;
        pick)    _jumplist_pick ;;
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

function jumplist-pick-widget() {
    # Save cursor, move to end, set beam cursor
    local saved_cursor="$CURSOR"
    CURSOR="${#BUFFER}"
    cursor beam-blink
    zle redisplay

    # Run picker
    _jumplist_pick
    local ret=$?

    # Restore cursor
    CURSOR="$saved_cursor"

    if (( ret == 0 )); then
        zle reset-prompt
        zle-mode-cursor
    else
        zle redisplay
        zle-mode-cursor
    fi
    return "$ret"
}

zle -N jumplist-back-widget
zle -N jumplist-forward-widget
zle -N jumplist-pick-widget

# Register chpwd hook
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _jumplist_chpwd
