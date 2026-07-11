# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 Matthew Mazzanti
#
#
# clip.zsh
#
# ZLE Clipboard Integration Helpers
# ================================
#
# Example Usage
# -------------
#
#   # Optional: provide your own backend (define before sourcing)
#   # function clip_copy()  { print -rn -- "$1" | some-clipboard-copy }
#   # function clip_paste() { some-clipboard-paste }
#
#   # Optional: customize which widgets are wrapped in each mode
#   # CLIP_PASTE_WIDGETS=(vi-put-after vi-put-before)
#   # CLIP_COPY_WIDGETS=(vi-yank)
#   # CLIP_BLACKHOLE_WIDGETS=(vi-yank)
#
#   # Load the module
#   source /path/to/clip.zsh
#
#   # Bind keys after sourcing
#   bindkey -M vicmd 'p' "$(clip_widget paste vi-put-after)"
#   bindkey -M vicmd 'P' "$(clip_widget paste vi-put-before)"
#   bindkey -M vicmd 'y' "$(clip_widget copy  vi-yank)"
#   bindkey -M vicmd 'Y' "$(clip_widget blackhole vi-yank)"
#
# -----------------------------------------------------------------------------
#
# Rather than replacing built-in widgets (e.g. vi-put-after, vi-yank), clip.zsh
# generates wrapper widgets that synchronize CUTBUFFER with the system clipboard
# before and/or after the original widget runs.
#
# This wrapper-based design plays well with other zsh modules that inject their
# own ZLE wrappers (which are often difficult to order correctly), and allows
# behavior to be adjusted by selecting different modes.
#
# The goal is to add predictable clipboard support while preserving normal ZLE
# semantics and limiting CUTBUFFER side effects.
#
# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
#
# Clipboard Backends
# ------------------
#
# Clipboard access is delegated to two functions:
#
#   clip_copy  <string>   # copy <string> to the system clipboard
#   clip_paste            # print clipboard contents to stdout
#
# Users may define these functions before sourcing clip.zsh to override
# clipboard behavior.
#
# If not defined, clip.zsh will attempt to configure them automatically
# using one of the following supported backends (in order):
#
#   - macOS:    pbcopy / pbpaste
#   - Wayland:  wl-copy / wl-paste
#   - X11:      xclip
#   - X11:      xsel
#
#
# Widget Groups
# -------------
#
# clip.zsh can automatically generate wrapper widgets for common ZLE
# commands. The following arrays control which base widgets are wrapped
# in each mode:
#
#   CLIP_PASTE_WIDGETS
#   CLIP_COPY_WIDGETS
#   CLIP_BLACKHOLE_WIDGETS
#
# Each variable should contain a list of ZLE widget names.
#
# If any of these variables are not defined, reasonable defaults are
# provided by the module.
#
# Example:
#
#   CLIP_PASTE_WIDGETS=(vi-put-after vi-put-before)
#   CLIP_COPY_WIDGETS=(vi-yank vi-yank-eol)
#   CLIP_BLACKHOLE_WIDGETS=(vi-yank)
#
# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------
#
#   clip_widget <mode> <widget>
#
# Returns the name of a generated wrapper widget for <widget> in <mode>. The
# returned name can be passed directly to bindkey.
#
# Supported modes: paste, copy, blackhole
#
#   paste      Paste from system clipboard
#   copy       Copy to system clipboard
#   blackhole  Ignore, do not update internal (CUTBUFFER) or system clipboards
#
# -----------------------------------------------------------------------------
# Internal Notes
# -----------------------------------------------------------------------------
#
# Wrapper widgets are generated with the name:
#
#   clip-<mode>-<widget>
#
# Each wrapper follows the same execution pattern:
#
#   1) Save current CUTBUFFER
#   2) Perform mode-specific synchronization
#   3) Invoke the base widget
#   4) Restore CUTBUFFER
#
# This design minimizes side effects and allows multiple wrappers
# to coexist without interfering with unrelated ZLE operations.
#
# New modes or backends should preserve this structure.

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
if (( ! ${+CLIP_PASTE_WIDGETS} )); then
  typeset -ga CLIP_PASTE_WIDGETS=(
    # vi mode
    put-replace-selection
    vi-put-after
    vi-put-after-swap
    vi-put-before
    vi-put-before-swap

    # emacs mode
    yank
  )
fi

if (( ! ${+CLIP_COPY_WIDGETS} )); then
  typeset -ga CLIP_COPY_WIDGETS=(
    # vi mode
    vi-change
    vi-change-eol
    vi-change-whole-line
    vi-delete
    vi-kill-eol
    vi-substitute
    vi-yank
    vi-yank-eol

    # emacs / region
    copy-region-as-kill
    kill-region

    # common kills
    backward-kill-line
    backward-kill-word
    kill-line
    kill-whole-line
    kill-word
  )
fi

if (( ! ${+CLIP_BLACKHOLE_WIDGETS} )); then
  typeset -ga CLIP_BLACKHOLE_WIDGETS=(
    # vi mode
    vi-change
    vi-change-eol
    vi-change-whole-line
    vi-delete
    vi-kill-eol
    vi-substitute
    vi-yank
    vi-yank-eol

    # emacs / region
    copy-region-as-kill
    kill-region

    # common kills
    backward-kill-line
    backward-kill-word
    kill-line
    kill-whole-line
    kill-word
  )
fi

# -----------------------------------------------------------------------------
# Public Functions
# -----------------------------------------------------------------------------

# Usage: clip_widget <mode> <widget>
#
# Prints:
#   - clip-<mode>-<widget> if that ZLE widget is defined
#   - otherwise prints <widget>
#
# Also prints a warning to stderr when falling back.
function clip_widget() {
  local mode="$1" widget="$2"
  local wrapper="clip-${mode}-${widget}"

  # Invalid mode -> fallback
  if [[ $mode != (paste|copy|blackhole) ]]; then
    print -u2 -r -- "clip: unknown mode: $mode (using base widget: $widget)"
    print -r -- "$widget"
    return 0
  fi

  # Wrapper missing -> fallback
  if (( ! $+widgets[$wrapper] )); then
    if ! [[ -n ${SSH_CONNECTION-}${SSH_CLIENT-}${SSH_TTY-} || ${TERM-} == linux* ]]; then
        print -u2 -r -- "clip: wrapper widget not defined: $wrapper (using base widget: $widget)"
    fi

    print -r -- "$widget"
    return 0
  fi

  # Success path
  print -r -- "$wrapper"
}

# -----------------------------------------------------------------------------
# Internals
# -----------------------------------------------------------------------------
function _clip_select_backend() {
  # If user provided both entrypoints, we're done.
  if (( $+functions[clip_copy] && $+functions[clip_paste] )); then
    return 0
  fi

  # If only one entrypoint is defined, error
  if (( $+functions[clip_copy] || $+functions[clip_paste] )); then
    return 1
  fi

  # Avoid “local clipboard” in common remote / no-GUI contexts.
  if [[ -n ${SSH_CONNECTION-}${SSH_CLIENT-}${SSH_TTY-} || ${TERM-} == linux* ]]; then
    return 1
  fi

  # Macos
  if (( $+commands[pbcopy] && $+commands[pbpaste] )); then
    functions[clip_copy]='print -rn -- "$1" | command pbcopy'
    functions[clip_paste]='command pbpaste'
    return 0
  fi

  # Linux - Wayland
  if (( $+commands[wl-copy] && $+commands[wl-paste] )) && [[ -n ${WAYLAND_DISPLAY-} ]]; then
    functions[clip_copy]='print -rn -- "$1" | command wl-copy'
    functions[clip_paste]='command wl-paste -n'
    return 0
  fi

  # Linux - X11, xclip
  if (( $+commands[xclip] )) && [[ -n ${DISPLAY-} ]]; then
    functions[clip_copy]='print -rn -- "$1" | command xclip -selection clipboard -in'
    functions[clip_paste]='command xclip -selection clipboard -out'
    return 0
  fi

  # Linux - X11, xsel
  if (( $+commands[xsel] )) && [[ -n ${DISPLAY-} ]]; then
    functions[clip_copy]='print -rn -- "$1" | command xsel --clipboard --input'
    functions[clip_paste]='command xsel --clipboard --output'
    return 0
  fi

  return 1
}

# Single implementation for all clip-<mode>-<base_widget> wrappers.
function _clip_wrapper_dispatch() {
  # mode = the chunk between "clip-" and the next "-"
  local mode="${${WIDGET#clip-}%%-*}"
  local base_widget="${WIDGET#clip-${mode}-}"

  local saved_cutbuffer="$CUTBUFFER" ret
  case "$mode" in
    paste)
      CUTBUFFER="$(clip_paste)"
      zle "$base_widget"
      ret=$?
      ;;
    copy)
      zle "$base_widget"
      ret=$?
      clip_copy "$CUTBUFFER"
      ;;
    blackhole)
      zle "$base_widget"
      ret=$?
      ;;
    *)
      print -u2 -r -- "clip: unknown mode: $mode"
      ret=2
      ;;
  esac

  CUTBUFFER="$saved_cutbuffer"
  return $ret
}

function _clip_define_widget() {
  local mode="$1" widget="$2"
  zle -N "clip-${mode}-${widget}" _clip_wrapper_dispatch
}

() {
  if ! _clip_select_backend; then
    return 0
  fi

  local widget
  for widget in "${CLIP_PASTE_WIDGETS[@]}"; do
    _clip_define_widget paste "$widget" || return "$?"
  done

  for widget in "${CLIP_COPY_WIDGETS[@]}"; do
    _clip_define_widget copy "$widget" || return "$?"
  done

  for widget in "${CLIP_BLACKHOLE_WIDGETS[@]}"; do
    _clip_define_widget blackhole "$widget" || return "$?"
  done

  unset \
    CLIP_PASTE_WIDGETS \
    CLIP_COPY_WIDGETS \
    CLIP_BLACKHOLE_WIDGETS \
    _clip_select_backend \
    _clip_render_wrapper_body \
    _clip_define_widget
}
