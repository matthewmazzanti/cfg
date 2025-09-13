export def --wrapped l [...args] {
    eza --classify --group-directories-first ...$args
}

export def --wrapped t [...args] {
    l --tree ...$args
}

$env.config.edit_mode = "vi"
$env.config.show_banner = false
$env.config.cursor_shape.emacs = "block"
$env.config.cursor_shape.vi_insert = "line"
$env.config.cursor_shape.vi_normal = "block"
$env.PROMPT_COMMAND_RIGHT = ""
