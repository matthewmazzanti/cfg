use ./lib.nu [direnv_hook]

$env.config = ($env.config | upsert hooks {
  pre_prompt: [ direnv_hook ]
})

$env.config.edit_mode = 'vi'
$env.config.show_banner = false
$env.config.cursor_shape.emacs = 'block'
$env.config.cursor_shape.vi_insert = 'line'
$env.config.cursor_shape.vi_normal = 'block'
$env.config.filesize.unit = 'metric'
$env.config.filesize.show_unit = true
if $env.TERM == 'xterm-ghostty' {
  $env.config.use_kitty_protocol = true
}

$env.PROMPT_COMMAND = do {
  use ./lib.nu [short-dir tilde-home color-path greek-letter]

  {||
    let colors = (if (is-admin) {
      { host: (ansi teal), seg: (ansi red), sep: (ansi light_red) }
    } else {
      { host: (ansi teal), seg: (ansi yellow), sep: (ansi light_yellow) }
    })

    let host = ^hostname
    | decode utf-8
    | if ($env.TERM != 'linux') {
      str substring 0..<1 | greek-letter
    } else {
      str substring 0..<2
    }

    # TODO: Shorten dynamically based on terminal width - requires nushell to
    # process resize events
    let dir = $env.PWD
    | tilde-home
    | short-dir
    | color-path $colors.seg $colors.sep

    $"($colors.host)($host)(ansi reset) ($dir)"
  }
}

$env.PROMPT_COMMAND_RIGHT = {||
  if ($env.LAST_EXIT_CODE == 0) {
    return ""
  }

  $"(ansi red)[(ansi light_red)error: ($env.LAST_EXIT_CODE)(ansi red)](ansi reset)"
}


def --wrapped wrapped_ls [...args] {
    ^eza --classify --group-directories-first --binary ...$args
}

def --wrapped tree [...args] {
    wrapped_ls --tree ...$args
}

alias list = ls
alias ls = wrapped_ls

let cfg = "~/src/nix/cfg" |path expand
