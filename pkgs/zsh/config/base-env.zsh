local hm="$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
[[ -f $hm ]] && source "$hm"

local brew=/opt/homebrew/bin/brew
[[ -x $brew ]] && eval "$("$brew" shellenv)"

# --- XDG Base Directories (HOME-based defaults) ---
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
