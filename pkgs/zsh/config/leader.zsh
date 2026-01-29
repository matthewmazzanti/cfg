# State
typeset -g leader_map=leader leader_prev_keymap

# Create empty leader map
bindkey -N "$leader_map"

# Enter leader (one-shot)
function leader-enter() {
  leader_prev_keymap=$KEYMAP
  zle -K "$leader_map"
}
zle -N leader-enter

# Exit leader (restore)
function leader-exit() {
  zle -K "${leader_prev_keymap:-vicmd}"
  leader_prev_keymap=
}
zle -N leader-exit

# Usage: leader-wrap <new-widget-name> <target-widget>
function leader-wrap() {
  local name=$1 target=$2
  if [[ -z $name || -z $target ]]; then
    return 2
  fi

  functions[$name]="${(qq)target}"'; leader-exit'
  zle -N "$name"
}

# Bind ; in vicmd
bindkey -M vicmd ';' leader-enter

# ESC exits leader
bindkey -M "$leader_map" '\e' leader-exit
