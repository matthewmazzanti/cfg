# The MIT License (MIT)
#
# Copyright (c) 2013–2025 Junegunn Choi
# Copyright (c) 2026 Matthew Mazzanti
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


: ${_FZF_LOADED:=0}
(( _FZF_LOADED || ! ${+commands[fd]} || ! ${+commands[fzf]} )) && return
typeset -g _FZF_LOADED=1

_fzf_common=(
    # Layout / UI
    --height='40%'
    --min-height='20+'
    --highlight-line
    --reverse
    --cycle
    # Key bindings
    --bind=ctrl-z:ignore
)

_fd_common=(
    --hidden
    --ignore
    --no-follow
    --exclude=.git/
    --strip-cwd-prefix
)

# Save cursor position to REPLY, move to end, set beam cursor
function fzf-cursor-save() {
    local saved="$CURSOR"
    CURSOR="${#BUFFER}"
    cursor beam-blink
    zle redisplay
    REPLY="$saved"
}

function fzf-print-history() {
    local nl=$'\n' indent=$'\n\t'
    local -A seen
    local id cmd
    for id cmd in "${(@kv)history}"; do
        (( ${+seen[$cmd]} )) && continue
        seen[$cmd]=1
        printf '%s\t%s\0' "$id" "${cmd//$nl/$indent}"
    done
}

function fzf-history-widget() {
    setopt pipefail
    local fzf_args=(
        "${_fzf_common[@]}"

        # History / mode
        --scheme=history

        # Input / parsing
        --delimiter=$'\t'
        --read0

        # Selection behavior
        --accept-nth=1
        --no-multi

        # Initial query
        --query="$BUFFER"
    )

    # Save current cursor position, move cursor to end of buffer
    fzf-cursor-save
    local saved_cursor="$REPLY"

    # Run fzf
    local selected="$(fzf-print-history | fzf "${fzf_args[@]}")"
    local ret="$?"

    # Restore cursor position
    CURSOR="$saved_cursor"

    # Read history entry into buffer
    if [[ -n "$selected" ]]; then
        zle vi-fetch-history -n "$selected"
    fi

    zle reset-prompt
    zle-mode-cursor
    return "$ret"
}
zle -N fzf-history-widget


# TODO: allow upwards traversal
function fzf-cd-widget() {
    local fd_args=("${_fd_common[@]}" --type=d --print0)
    local fzf_args=("${_fzf_common[@]}" --scheme=path --no-multi --read0)

    # Save current cursor position, move cursor to end of buffer
    fzf-cursor-save
    local saved_cursor="$REPLY"

    # Run the picker
    local selected="$(fd "${fd_args[@]}" | fzf "${fzf_args[@]}")"
    local ret="$?"

    # Restore cursor position
    CURSOR="$saved_cursor"

    if (( ret == 0 && ${#selected} > 0 )); then
        cd "$selected"
        ret="$?"
        zle reset-prompt
        zle-mode-cursor
        return "$ret"
    fi

    zle redisplay
    zle-mode-cursor
    return "$ret"
}
zle -N fzf-cd-widget


function fzf-file-widget() {
    local fd_args=("${_fd_common[@]}" --type=f --print0)
    local fzf_args=("${_fzf_common[@]}" --multi --scheme=path --read0 --print0)

    # Save current cursor position, move cursor to end of buffer
    fzf-cursor-save
    local saved_cursor="$REPLY"

    # Run the picker
    local selected="$(fd "${fd_args[@]}" | fzf "${fzf_args[@]}")"
    local ret="$?"

    # Restore cursor position
    CURSOR="$saved_cursor"

    # Insert at cursor / replace region (helper handles quoting + spacing)
    if (( ret == 0 && ${#selected} > 0 )); then
        zle-insert-words "${(@R)${(0)selected}:#}"
    fi

    zle redisplay
    zle-mode-cursor
    return "$ret"
}
zle -N fzf-file-widget
