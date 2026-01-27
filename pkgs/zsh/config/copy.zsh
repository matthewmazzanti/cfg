# Clipboard ↔ CUTBUFFER integration for ZLE (vi-mode friendly)
#
# Goal:
# - Keep Zsh’s CUTBUFFER in sync with the system clipboard when using common
#   vi-mode widgets (yank/change/delete/put).
#
# Approach:
# - Detect a clipboard backend for the *current session* and define:
#     _clip_copy  (string -> system clipboard)
#     _clip_paste (system clipboard -> string)
# - Wrap selected ZLE widgets so they “chain”:
#     copy-widgets  : run original widget, then _clip_copy "$CUTBUFFER"
#     paste-widgets : set CUTBUFFER="$(_clip_paste)", then run original widget
#
# Safety / UX:
# - Disabled on SSH sessions (remote clipboard should not implicitly affect local)
# - Disabled on TERM=linux (no GUI clipboard; avoid broken/hanging backends)

# ---------------------------------------------------------------------------
# Backend selection (returns success iff enabled)
# ---------------------------------------------------------------------------

function _clip_select_backend() {
  # Returns 0 iff a usable clipboard backend is configured for this session.
  # On success, defines uniform entrypoints:
  #   _clip_copy  : copies its first argument to the system clipboard
  #   _clip_paste : prints clipboard contents (ideally without a trailing newline)

  if [[ -n ${SSH_CONNECTION-}${SSH_CLIENT-}${SSH_TTY-} || ${TERM-} == linux ]]; then
    return 1
  fi

  if (( $+commands[pbcopy] && $+commands[pbpaste] )); then
    functions[_clip_copy]='print -rn -- "$1" | command pbcopy;'
    functions[_clip_paste]='command pbpaste;'
    return 0
  fi

  if (( $+commands[wl-copy] && $+commands[wl-paste] )) && [[ -n ${WAYLAND_DISPLAY-} ]]; then
    functions[_clip_copy]='print -rn -- "$1" | command wl-copy;'
    functions[_clip_paste]='command wl-paste -n;'
    return 0
  fi

  if (( $+commands[xclip] )) && [[ -n ${DISPLAY-} ]]; then
    functions[_clip_copy]='print -rn -- "$1" | command xclip -selection clipboard -in;'
    functions[_clip_paste]='command xclip -selection clipboard -out;'
    return 0
  fi

  if (( $+commands[xsel] )) && [[ -n ${DISPLAY-} ]]; then
    functions[_clip_copy]='print -rn -- "$1" | command xsel --clipboard --input;'
    functions[_clip_paste]='command xsel --clipboard --output;'
    return 0
  fi

  return 1
}

# ---------------------------------------------------------------------------
# Widget wrapping (chaining)
# ---------------------------------------------------------------------------

function _clip_wrap_widgets() {
  # Wrap one or more existing ZLE widgets, preserving original behavior and
  # adding clipboard synchronization.
  #
  # Why `zle -A` here?
  # - `zle -A old new` aliases an existing widget under a new name, which is a
  #   clean fit for “wrap the current definition, whatever it is right now”.
  # - This is robust against whether the widget is a builtin, a user-defined
  #   widget, or already provided by another plugin: you always chain to the
  #   saved alias.
  # - Many plugins instead redefine widgets “by hand” (e.g. calling a known
  #   builtin like `.vi-yank`, or reimplementing logic) because:
  #     * they want a fixed implementation (not whatever is currently installed),
  #     * they need to wrap multiple layers and/or control ordering explicitly,
  #     * they’re avoiding name indirection / aliasing for portability/style,
  #     * they’re targeting specific widgets that may not exist in all setups.
  #   For this plugin’s goal (simple chaining), `zle -A` is the direct tool.
  #
  # Implementation notes:
  # - zle -A saves the original widget under a private name.
  # - We generate wrapper function bodies as strings to splice the saved widget
  #   name as a literal `zle <widget>` call.

  local mode="$1"; shift
  local widget

  for widget in "$@"; do
    local saved_widget="_clip_orig__${widget}"
    zle -A "$widget" "$saved_widget"

    local wrap_fn="_clip_wrap__${mode}__${widget}"
    case "$mode" in
      copy)
        functions[$wrap_fn]='
            zle '"$saved_widget"' -- "$@"
            _clip_copy "$CUTBUFFER"
        '
        ;;
      paste)
        functions[$wrap_fn]='
            CUTBUFFER="$(_clip_paste)"
            zle '"$saved_widget"' -- "$@"
        '
        ;;
      *)
        return 2
        ;;
    esac

    zle -N "$widget" "$wrap_fn"
  done
}

if _clip_select_backend; then
  _clip_wrap_widgets copy \
    vi-yank \
    vi-yank-eol \
    vi-change \
    vi-change-eol \
    vi-change-whole-line \
    vi-delete \
    vi-kill-eol

  _clip_wrap_widgets paste \
    vi-put-before \
    vi-put-after \
    put-replace-selection
fi

unset _clip_select_backend _clip_wrap_widgets
