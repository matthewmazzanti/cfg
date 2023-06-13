autoload -Uz add-zsh-hook

# TODO: -s flag may be macos specific
local prompt_leader="$(hostname -s)" 
case "$prompt_leader" in
    lambda)
        prompt_leader="λ"
        ;;
    omega)
        prompt_leader="ω"
        ;;
    iota)
        prompt_leader="ι"
        ;;
    beta)
        prompt_leader="β"
        ;;
    delta)
        prompt_leader="δ"
        ;;
esac

local prompt_vi_mode="insert"
function zle-keymap-select zle-line-init {
    case "$KEYMAP" in
        "vicmd")
            prompt_vi_mode="command"
            print -n '\033[1 q'
            ;;
        "viins"|"main")
            prompt_vi_mode="insert"
            print -n '\033[5 q'
            ;;
    esac

    zle reset-prompt
    zle -R
}

zle -N zle-keymap-select
zle -N zle-line-init

function reset-cursor() {
    print -n '\033[1 q'
}

add-zsh-hook zshexit reset-cursor

function prompt-color() {
    printf '%%F{%s}%s%%f' "$1" "$2"
}

function prompt-leader() {
    local color='cyan'

    case "$prompt_vi_mode" in
        "insert")
            color='cyan'
            ;;
        "command")
            color='white'
            ;;
    esac

    prompt-color "$color" "$prompt_leader "
}

function prompt-pwd() {
    local color='yellow'
    local long='4'

    if (( $COLUMNS < 50 )); then
        long='1'
    elif (( $COLUMNS < 100 )); then
        long='2'
    elif (( $COLUMNS < 150 )); then
        long='3'
    fi

    prompt-color "$color" "$(short-pwd -k $long) "
}

setopt PROMPT_SUBST
# TODO: Get the short pwd script working again
# PROMPT='$(prompt-leader)$(prompt-pwd)';
PROMPT='$(prompt-leader)%F{yellow}%~%f '
RPROMPT='';

local prompt_clear=1
local prompt_cmd_run=0
function post-command() {
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

add-zsh-hook precmd post-command

function set-prompt-cmd-run() {
    prompt_cmd_run=1
}

add-zsh-hook preexec set-prompt-cmd-run

function clear() {
    prompt_clear=1
    /usr/bin/clear
}
