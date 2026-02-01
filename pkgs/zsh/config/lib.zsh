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

function cursor() {
  case "$1" in
    reset)           print -n '\e[0 q' ;;
    block-blink)     print -n '\e[1 q' ;;
    block)           print -n '\e[2 q' ;;
    underline-blink) print -n '\e[3 q' ;;
    underline)       print -n '\e[4 q' ;;
    beam-blink)      print -n '\e[5 q' ;;
    beam)            print -n '\e[6 q' ;;
    hide)            print -n '\e[?25l' ;;
    show)            print -n '\e[?25h' ;;
    *)
      print "Usage: cursor {block|block-blink|beam|beam-blink|underline|underline-blink|default|hide|show}" >&2
      return 1
      ;;
  esac
}

function zle-mode-cursor() {
    local keymap="$KEYMAP"
    # Set cursor based on current keymap.
    case "$KEYMAP" in
        vicmd|visual)  cursor block-blink ;;
        *)             cursor beam-blink ;;
    esac
}
