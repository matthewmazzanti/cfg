# ----------------------------
# prompt.zsh
#
# A small Zsh prompt with:
# - vi-mode cursor shaping (beam in insert, block in command)
# - a compact, width-aware PWD renderer
# - a post-command “spacer line” and optional exit-status banner
#
# Design notes:
# - PROMPT_SUBST is enabled so PROMPT can call functions.
# - The vi-mode cursor logic uses ZLE widgets (zle-keymap-select / zle-line-init).
# - The post-command spacer uses hooks: preexec marks “a command ran”, precmd prints
#   a newline (and optionally an error banner) only when appropriate.
# - We avoid overriding builtins by default; a clear wrapper + optional alias is provided.
# ----------------------------

autoload -Uz add-zsh-hook
setopt PROMPT_SUBST

# ----------------------------
# Colors
#
# prompt_fg is a simple lookup table for 16-color ANSI foregrounds (zsh %F escape)
# plus a "reset" entry (%f). These are intended for prompt-time expansion, so the
# values are stored as zsh prompt escapes rather than literal terminal sequences.
#
# Example:
#   print -P "${prompt_fg[red]}hello${prompt_fg[reset]}"
# ----------------------------

typeset -gA prompt_fg=(
    black          "%F{0}"
    red            "%F{1}"
    green          "%F{2}"
    yellow         "%F{3}"
    blue           "%F{4}"
    magenta        "%F{5}"
    cyan           "%F{6}"
    white          "%F{7}"

    bright-black   "%F{8}"
    bright-red     "%F{9}"
    bright-green   "%F{10}"
    bright-yellow  "%F{11}"
    bright-blue    "%F{12}"
    bright-magenta "%F{13}"
    bright-cyan    "%F{14}"
    bright-white   "%F{15}"

    reset          "%f"
)

function prompt_accent_color() {
    local color=cyan
    if [[ -n $SSH_CONNECTION || -n $SSH_CLIENT || -n $SSH_TTY ]]; then
        color=blue
    fi
    print -r -- "$color"
}

# ----------------------------
# Cursor shape + vi mode integration
#
# These use DECSCUSR ("Set Cursor Style") escape sequences supported by many
# terminals. Common values:
#   \033[1 q  -> blinking block (often rendered as a steady block)
#   \033[5 q  -> blinking bar (often rendered as a steady beam)
#
# We update cursor style when the ZLE keymap changes:
# - vicmd  : block cursor
# - others: beam cursor
#
# We also force block cursor on preexec / zshexit so that:
# - when a command runs, the cursor won’t remain a beam in programs that don’t
#   restore it
# - when leaving an SSH session, you reset to a sane default
# ----------------------------

# Print escape code to set cursor to block for command mode
function prompt_block_cursor() {
    cursor block-blink
}

# ZLE widget: called when keymap changes or when the editor initializes.
# KEYMAP is set by ZLE and is only meaningful inside widgets/hooks that ZLE
# runs.
function prompt_update_mode() {
    zle-mode-cursor
    # Redraw prompt so prompt elements that depend on KEYMAP (e.g. separator
    # char) update immediately.
    zle reset-prompt
}

# ----------------------------
# Prompt pieces
#
# Each of these functions prints a piece of prompt text. They are composed in
# PROMPT below. The functions use print -r (raw) to avoid unexpected escapes.
# ----------------------------

function prompt_shlvl() {
    local n=$(( SHLVL - 1 ))
    if (( n <= 0 )); then
        return
    fi

    local char="›"
    if [[ "$TERM" == linux ]]; then
        char=">"
    fi

    print -r -- "${prompt_fg[bright-black]}$n$char ${prompt_fg[reset]}"
}

# Translate the first letter of a string to a Greek-ish glyph. This is purely
# aesthetic and intended for short hostnames.
#
# Terminal caveat:
# - On the Linux virtual console ($TERM == linux), Unicode glyph coverage is
#   often limited. In that case we return the original string unchanged.
function prompt_greek_letter() {
    local input="$1"

    if [[ "$TERM" == "linux" ]]; then
        print -r -- "$input"
        return
    fi

    case "${input[1,1]:l}" in
        a) print "α" ;;  # alpha
        b) print "β" ;;  # beta
        c) print "χ" ;;  # chi
        d) print "δ" ;;  # delta
        e) print "ε" ;;  # epsilon
        f) print "φ" ;;  # phi
        g) print "γ" ;;  # gamma
        h) print "η" ;;  # eta
        i) print "ι" ;;  # iota
        j) print "j" ;;  # no Greek, keep Latin
        k) print "κ" ;;  # kappa
        l) print "λ" ;;  # lambda
        m) print "μ" ;;  # mu
        n) print "ν" ;;  # nu
        o) print "ω" ;;  # omega
        p) print "π" ;;  # pi
        q) print "θ" ;;  # theta (convention)
        r) print "ρ" ;;  # rho
        s) print "σ" ;;  # sigma
        t) print "τ" ;;  # tau
        u) print "υ" ;;  # upsilon
        v) print "ν" ;;  # same as n
        w) print "ω" ;;  # omega
        x) print "ξ" ;;  # xi
        y) print "ψ" ;;  # psi
        z) print "ζ" ;;  # zeta
        *) print -r -- "$input" ;;
    esac
}

# Leader segment: currently just the hostname in cyan.
function prompt_leader() {
    local color="$(prompt_accent_color)"
    print -r -- "${prompt_fg[$color]}$prompt_hostname${prompt_fg[reset]}"
}

# PWD segment:
# - Rewrites $HOME prefix to "~"
# - Splits path into segments
# - Shortens earlier segments to `shorten_to` characters, but keeps the last
#   `keep_long` segments unshortened.
#
# keep_long is derived from terminal width: wider terminals keep more segments.
function prompt_pwd() {
    local shorten_to=1

    local keep_long=$(( ${COLUMNS:-0} / 50 + 1 ))
    if (( keep_long < 1 )); then
        keep_long=1
    fi
    if (( keep_long > 4 )); then
        keep_long=4
    fi

    local dir=$PWD
    if [[ $dir == $HOME(|/*) ]]; then
        dir="~${dir#$HOME}"
    fi

    local -a segs
    segs=(${(s:/:)dir})

    local cutoff=$(( ${#segs} - keep_long ))
    if (( cutoff < 0 )); then
        cutoff=0
    fi

    local i seg
    for (( i = 1; i <= cutoff; i++ )); do
        seg=$segs[i]

        # Keep dot-prefix meaning when shortening hidden dirs:
        # e.g. ".config" -> ".c" (or ".co" if shorten_to >= 2)
        if (( ${#seg} > shorten_to )); then
            if [[ $seg == .* ]] && (( shorten_to < 2 )); then
                segs[i]=${seg[1,2]}
            else
                segs[i]=${seg[1,shorten_to]}
            fi
        fi
    done

    # Render with colored separators:
    # - bright-yellow "/" between segments
    # - yellow text for segment names
    local out=""
    for (( i = 1; i <= ${#segs}; i++ )); do
        if (( i > 1 )); then
            out+="${prompt_fg[bright-yellow]}/"
        fi

        out+="${prompt_fg[yellow]}${segs[i]}"
    done

    # Final reset so the rest of the prompt isn't yellow.
    print -r -- "$out%f"
}

# Separator segment changes with vi-mode:
# - vicmd: ":" (command mode)
# - else : ">" (insert/emacs/etc)
function prompt_separator() {
    local char=":"
    case "$KEYMAP" in
        vicmd) char=":" ;;
        *)     char=">" ;;
    esac

    local color="$(prompt_accent_color)"
    print -r -- "${prompt_fg[$color]}$char${prompt_fg[reset]}"
}

# ----------------------------
# Post-prompt newline + exit status
#
# Goal: visually separate command output from the next prompt, but avoid printing
# an extra blank line on the very first prompt after startup, or immediately
# after a clear-screen.
#
# Mechanism:
# - preexec sets prompt_cmd_run=1 for real commands
# - precmd runs right before the next prompt is displayed; we conditionally print:
#     - blank line on success
#     - "[error: N]" banner + newline on failure
#
# State:
# - prompt_clear: set to 1 when the screen is considered "fresh" (startup or clear)
# - prompt_cmd_run: set to 1 when a command has run since last prompt
# ----------------------------

prompt_clear=1
prompt_cmd_run=0

function prompt_post_command() {
    local exit_code="$?"

    if (( prompt_clear == 0 && prompt_cmd_run == 1 )); then
        if (( exit_code > 0 )); then
            print -P "${prompt_fg[red]}[${prompt_fg[bright-red]}error: $exit_code${prompt_fg[red]}]${prompt_fg[reset]}\n"
        else
            print
        fi
    fi

    prompt_clear=0
    prompt_cmd_run=0
}

function prompt_set_cmd_run() {
    prompt_cmd_run=1
}

# Clear-screen helper:
# Marks the screen as "fresh" so the next prompt appears without an extra spacer.
function prompt_clear_screen() {
    prompt_clear=1
    command clear
}

# ----------------------------
# Init (call once when sourced)
# ----------------------------

() {
    prompt_hostname="$(prompt_greek_letter "$(hostname -s)")"

    zle -N zle-keymap-select prompt_update_mode
    zle -N zle-line-init     zle-mode-cursor

    # When entering/leaving an SSH session or running a command, prefer block.
    add-zsh-hook zshexit  prompt_block_cursor
    add-zsh-hook preexec  prompt_block_cursor

    add-zsh-hook precmd  prompt_post_command
    add-zsh-hook preexec prompt_set_cmd_run

    PROMPT='$(prompt_shlvl)$(prompt_leader) $(prompt_pwd)$(prompt_separator) '
    RPROMPT=""
    if [[ "$TERM" != linux ]]; then
        PS2='↳ '
    fi

    alias clear=prompt_clear_screen
}
