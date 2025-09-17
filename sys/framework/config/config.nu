
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

$env.PROMPT_COMMAND_RIGHT = ""


$env.prompt.ran_command = false

def --env pre_execution [] {
  let cmd = commandline | str trim
  if $cmd != '' and not ($cmd starts-with 'clear') {
    $env.prompt.ran_command = true
  }
}

def --env pre_prompt [] {
  # Check if we ran anything
  if not $env.prompt.ran_command {
    return
  }
  $env.prompt.ran_command = false

  # Print error code in red
  if $env.LAST_EXIT_CODE > 0  {
    print $"(ansi red)[(ansi light_red)error: ($env.LAST_EXIT_CODE)(ansi red)](ansi reset)"
  }

  # Add newline between command runs
  print ''
}

$env.config = ($env.config | upsert hooks {
  pre_execution: [ pre_execution ],
  pre_prompt: [ pre_prompt ]
})

def --wrapped wrapped_ls [...args] {
    eza --classify --group-directories-first ...$args
}

def --wrapped tree [...args] {
    wrapped_ls --tree ...$args
}

alias l = ls
alias ls = wrapped_ls
