# Hook vi-mode yanks into global copy/paste buffer
function clip-wrap-widgets() {
    local copy_or_paste=$1
    shift

    for widget in $@; do
        if [[ $copy_or_paste == "copy" ]]; then
            eval "
            function _clip-wrapped-$widget() {
                zle .$widget
                print -rn \"\$CUTBUFFER\" | pbcopy
            }
            "
        else
            eval "
            function _clip-wrapped-$widget() {
                CUTBUFFER=\"\$(pbpaste)\"
                zle .$widget
            }
            "
        fi

        zle -N "clip-$widget" "_clip-wrapped-$widget"
    done
}

local copy_widgets=(
    vi-yank
    vi-yank-eol
    vi-change
    vi-change-eol
    vi-change-whole-line
    vi-delete
    vi-kill-eol
)
local paste_widgets=(
    vi-put-{before,after}
    put-replace-selection
)

clip-wrap-widgets copy $copy_widgets
clip-wrap-widgets paste  $paste_widgets
