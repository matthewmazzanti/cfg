autoload -Uz add-zsh-hook

# TODO: -s flag may be macos specific
local prompt_hostname="$(hostname -s)"
case "$prompt_hostname" in
    lambda) prompt_hostname="λ";;
    omega)  prompt_hostname="ω";;
    iota)   prompt_hostname="ι";;
    beta)   prompt_hostname="β";;
    delta)  prompt_hostname="δ";;
esac

# Print escape code to set cursor to block for command mode
function prompt_block_cursor() {
    print -n '\033[1 q'
}

# Print escape code to set cursor to beam for insert mode
function prompt_beam_cursor() {
    print -n '\033[5 q'
}

# Save the vi mode to a local variable, and update cursor appropriately. The
# local variable "$KEYMAP" is only available in this widget. (maybe, need to
# double check)
local prompt_vi_mode="insert"
function prompt_save_mode() {
    # Save keymap, update cursor
    case "$KEYMAP" in
        "vicmd")
            prompt_vi_mode="command"
            prompt_block_cursor
            ;;
        "viins"|"main")
            prompt_vi_mode="insert"
            prompt_beam_cursor
            ;;
    esac

    # Reset and redraw prompt to update color
    zle reset-prompt
    zle -R
}

# Bind widgets
zle -N zle-keymap-select prompt_save_mode
zle -N zle-line-init prompt_save_mode
# When entering an SSH session, reset cursor to block
add-zsh-hook zshexit prompt_block_cursor

# Render a zsh prompt color string like "%F{yellow}foobar%f"
function prompt_color() {
    printf "%%F{%s}%s%%f" "$1" "$2"
}

# Change color of hostname based off of mode
function prompt_leader() {
    local color="cyan"

    case "$prompt_vi_mode" in
        "insert")
            color="cyan"
            ;;
        "command")
            color="white"
            ;;
    esac

    prompt_color "$color" "$prompt_hostname "
}

# Print responsive PWD based off of COLUMNS
function prompt_pwd() {
    local color="yellow"
    local long="4"

    if (( "$COLUMNS" < 50 )); then
        long="1"
    elif (( "$COLUMNS" < 100 )); then
        long="2"
    elif (( "$COLUMNS" < 150 )); then
        long="3"
    fi

    prompt_color "$color" "$(short-pwd -k $long) "
}

setopt PROMPT_SUBST
# TODO: Get the short pwd script working again
# PROMPT='$(prompt_leader)$(prompt_pwd)';
PROMPT='$(prompt_leader)%F{yellow}%~%f '
RPROMPT="";

# Render post-prompt items:
# - A newline, if a command was run
# - A message like "[error: 1]" if a command exited with a code
#
# Pre-command is the only hook to do what we want, so a bit of trickery is
# needed. Instead of always printing a newline, only print if the a command has
# just been run. This makes the first prompt after startup or clear render at
# the first row, and subsequent rows have a nice space between.
local prompt_clear=1
local prompt_cmd_run=0
function prompt_post_command() {
    local exit_code="$?"
    if (( "$prompt_clear" == 0 && "$prompt_cmd_run" == 1 )); then 
        if (( "$exit_code" > 0 )); then
            echo -e "\e[0;31m[error: $exit_code]\e[0m\n"
        else
            echo
        fi
    fi

    prompt_clear=0
    prompt_cmd_run=0
}

add-zsh-hook precmd prompt_post_command

function prompt_set_cmd_run() {
    prompt_cmd_run=1
}

add-zsh-hook preexec prompt_set_cmd_run

# I think this handles ^L, not sure
function clear() {
    prompt_clear=1
    command clear
}
