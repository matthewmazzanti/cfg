# Select clipboard backend, store as argv arrays.
function _clip_select_backend() {
  # Disable integration on SSH or Linux console
  [[ -n ${SSH_CONNECTION-}${SSH_CLIENT-}${SSH_TTY-} || ${TERM-} == linux ]] && return

  typeset -ga clip_copy_cmd clip_paste_cmd

  if (( $+commands[pbcopy] && $+commands[pbpaste] )); then
    clip_copy_cmd=(pbcopy)
    clip_paste_cmd=(pbpaste)

  elif (( $+commands[wl-copy] && $+commands[wl-paste] )) && [[ -n ${WAYLAND_DISPLAY-} ]]; then
    clip_copy_cmd=(wl-copy)
    clip_paste_cmd=(wl-paste -n)

  elif (( $+commands[xclip] )) && [[ -n ${DISPLAY-} ]]; then
    clip_copy_cmd=(xclip -selection clipboard -in)
    clip_paste_cmd=(xclip -selection clipboard -out)

  elif (( $+commands[xsel] )) && [[ -n ${DISPLAY-} ]]; then
    clip_copy_cmd=(xsel --clipboard --input)
    clip_paste_cmd=(xsel --clipboard --output)
  fi
}

# Wrap ZLE widgets so CUTBUFFER syncs to the system clipboard.
# If the relevant backend (copy/paste) isn't available, the wrapper is a pass-through.
function _clip_wrap_widgets() {
  local mode=$1
  shift

  local widget
  for widget in "$@"; do
    case $mode in
      copy)
        if [[ -n ${clip_copy_cmd+x} ]]; then
          eval "
          function _clip_wrapped_$widget() {
            zle .$widget
            print -rn -- \"\$CUTBUFFER\" | command \"\${clip_copy_cmd[@]}\"
          }
          "
        else
          eval "
          function _clip_wrapped_$widget() {
            zle .$widget
          }
          "
        fi
        ;;
      paste)
        if [[ -n ${clip_paste_cmd+x} ]]; then
          eval "
          function _clip_wrapped_$widget() {
            CUTBUFFER=\"\$(command \"\${clip_paste_cmd[@]}\")\"
            zle .$widget
          }
          "
        else
          eval "
          function _clip_wrapped_$widget() {
            zle .$widget
          }
          "
        fi
        ;;
      *)
        return 2
        ;;
    esac

    zle -N "clip-$widget" "_clip_wrapped_$widget"
  done
}

# --- Setup -----------------------------------------------------------------

_clip_select_backend

# Copy-affecting widgets
_clip_wrap_widgets copy \
  vi-yank \
  vi-yank-eol \
  vi-change \
  vi-change-eol \
  vi-change-whole-line \
  vi-delete \
  vi-kill-eol

# Paste-affecting widgets
_clip_wrap_widgets paste \
  vi-put-before \
  vi-put-after \
  put-replace-selection

unset -f _clip_select_backend _clip_wrap_widgets
