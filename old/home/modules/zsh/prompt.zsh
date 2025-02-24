export ZSH_VI_MODE="insert"

case "$(hostname)" in
    lambda)
        LEADER="λ"
        ;;
    omega)
        LEADER="ω"
        ;;
    iota)
        LEADER="ι"
        ;;
    *)
        LEADER="$(hostname)"
        ;;
esac

function zle-keymap-select zle-line-init
{
    case "$KEYMAP" in
        "vicmd")
            ZSH_VI_MODE="command"
            print -n '\033[1 q'
            ;;
        "viins"|"main")
            ZSH_VI_MODE="insert"
            print -n '\033[5 q'
            ;;
    esac

    zle reset-prompt
    zle -R
}

zle -N zle-keymap-select
zle -N zle-line-init

function prompt-color() {
    printf '%%F{%s}%s%%f' "$1" "$2"
}

function prompt-leader() {
    local color='cyan'

    case "$ZSH_VI_MODE" in
        "insert")
            color='cyan'
            ;;
        "command")
            color='white'
            ;;
    esac

    prompt-color "$color" "$LEADER "
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
PROMPT='$(prompt-leader)$(prompt-pwd)';
RPROMPT='';
