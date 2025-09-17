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

$env.PROMPT_COMMAND = {||
  use ./lib.nu [short-dir tilde-home color-path greek-letter]

  let colors = (if (is-admin) {
    { host: (ansi teal), seg: (ansi red), sep: (ansi light_red) }
  } else {
    { host: (ansi teal), seg: (ansi yellow), sep: (ansi light_yellow) }
  })

  let host = ^hostname
  | decode utf-8
  | if ($env.TERM != "linux") {
    $in | str substring 0..<1 | greek-letter
  } else {
    $in | str substring 0..<2
  }

  # TODO: Shorten dynamically based on terminal width - requires nushell to
  # process resize events
  let dir = $env.PWD
  | tilde-home
  | short-dir
  | color-path $colors.seg $colors.sep


  $"($colors.host)($host)(ansi reset) ($dir)"
}

$env.PROMPT_COMMAND_RIGHT = ""



$env.config = ($env.config | upsert hooks {
  pre_prompt: [
    {||
      if $env.LAST_EXIT_CODE > 0  {
        print $"(ansi red)[error: ($env.LAST_EXIT_CODE)](ansi reset)"
      }
    }
  ]
})
