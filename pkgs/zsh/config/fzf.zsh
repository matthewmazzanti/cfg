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
    local saved_cursor="$CURSOR"
    CURSOR="${#BUFFER}"
    zle redisplay

    # Run fzf
    local selected="$(fzf-print-history | fzf "${fzf_args[@]}")"
    local ret="$?"

    # Restore cursor position
    CURSOR="$saved_cursor"

    if [[ -n "$selected" ]]; then
        zle vi-fetch-history -n "$selected"
    fi

    zle redisplay
    return "$ret"
}
zle -N fzf-history-widget


# TODO: allow upwards traversal
function fzf-cd-widget() {
  local fd_args=("${_fd_common[@]}" --type=d --print0)
  local fzf_args=("${_fzf_common[@]}" --scheme=path --no-multi --read0)

  # Save current cursor position, move cursor to end of buffer
  local saved_cursor="$CURSOR"
  CURSOR="${#BUFFER}"
  zle redisplay

  # Run the picker
  local selected="$(fd "${fd_args[@]}" | fzf "${fzf_args[@]}")"
  local ret="$?"

  # Restore cursor position
  CURSOR="$saved_cursor"

  if (( ret && ${#selected} > 0 )); then
    cd "$selected"
    ret="$?"
    zle reset-prompt
    return "$ret"
  fi

  zle redisplay
  return "$ret"
}
zle -N fzf-cd-widget

# Insert one or more shell-quoted words into the ZLE buffer at the cursor or
# active selection.
#
# - Replaces the active region if present, otherwise inserts at point.
# - Preserves correct behavior for vi block-cursor modes.
# - Ensures exactly one space of separation from surrounding text when needed.
# - Quotes all arguments for safe shell re-insertion.
#
# This is intended as a helper for picker/completion widgets that return
# multiple words to be spliced into the current command line.
function zle-insert-words() {
  if (( $# == 0 )); then
    return 0
  fi

  # Cursor is "on a character" (block cursor semantics) in these keymaps
  local is_block_cursor=0
  [[ "$KEYMAP" == (vicmd|visual) ]] && is_block_cursor=1

  # We have something selected
  local has_selection=$(( REGION_ACTIVE && MARK != CURSOR ))

  # Calculate replacement range
  local start stop
  if (( has_selection )); then
    if (( MARK < CURSOR )); then
      start=$MARK
      stop=$CURSOR
    else
      start=$CURSOR
      stop=$MARK
    fi

    stop=$(( stop + is_block_cursor ))
  else
    # No region: empty range at insertion point
    local pos=$(( CURSOR + is_block_cursor ))
    start=$pos
    stop=$pos
  fi

  # Basically a corrected LBUFFER/RBUFFER for insert-after-vi semantics
  local left="${BUFFER[1,start]}" right="${BUFFER[stop+1,-1]}"

  # Quoted input variables, string to insert into shell
  local inserted="${(q@)@}"

  # Ensure the inserted text is separated from surrounding text by single
  # spaces, adding padding only when needed.
  #
  # Examples (| = insertion point, X = inserted text):
  #
  #   "foo|bar"   -> "foo X bar"
  #   "foo |bar"  -> "foo X bar"
  #   "foo| bar"  -> "foo X bar"
  #   "foo | bar" -> "foo X bar"
  #   "|bar"      -> "X bar"
  #   "foo|"      -> "foo X"
  #   "|"         -> "X"
  local lead=' ' trail=' '
  [[ -z $left  || ${left[-1]}  == [[:space:]] ]] && lead=''
  [[ -z $right || ${right[1]}  == [[:space:]] ]] && trail=''

  # We can rebuild him
  BUFFER="${left}${lead}${inserted}${trail}${right}"

  # Update ZLE state to match what we want - cursor at the end of insert,
  # adjusted for mode, and no selection
  CURSOR=$(( ${#left} + ${#lead} + ${#inserted} + 1 - is_block_cursor ))
  if (( has_selection )); then
    zle deactivate-region
    MARK=$CURSOR
  fi
}

function fzf-file-widget() {
  local fd_args=("${_fd_common[@]}" --type=f --print0)
  local fzf_args=("${_fzf_common[@]}" --multi --scheme=path --read0 --print0)

  # Save current cursor position, move cursor to end of buffer
  local saved_cursor="$CURSOR"
  CURSOR="${#BUFFER}"
  zle redisplay

  # Run the picker
  local selected="$(fd "${fd_args[@]}" | fzf "${fzf_args[@]}")"
  local ret="$?"

  # Restore cursor position
  CURSOR="$saved_cursor"

  # Insert at cursor / replace region (helper handles quoting + spacing)
  if (( ret == 0 && ${#selected} >= 0 )); then
      zle-insert-words "${(@R)${(0)selected}:#}"
  fi

  zle redisplay
  return "$ret"
}
zle -N fzf-file-widget
