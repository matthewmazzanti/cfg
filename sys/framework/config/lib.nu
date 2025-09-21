export def build-path-converter [sep: string] {
  {
    from_string: {|s| $s | split row $sep | path expand --no-symlink }
    to_string: {|v| $v | path expand --no-symlink | str join $sep }
  }
}

export def convert-env [] {
  items {|key value|
    let default = { $key: $value }
    if ($value == null) {
      return $default
    }

    let from_string = ($env.ENV_CONVERSIONS | get -o $key).from_string?
    if ($from_string | is-empty) {
      return $default
    }

    { $key: (do $from_string $value) }
  }
  | into record
}

export def sh-env [] {
  # Exported function that sources a POSIX shell script and loads its exported
  # environment variables into the current Nushell environment.

  # Run /bin/sh to source the script, then print the environment as
  # NUL-separated.
  # - We use escape-arg to safely pass the script path (handles quotes in
  #   filenames).
  # - `env -0` prints each KEY=VAL pair separated by a NUL character for safe
  #   parsing.
  path expand
  | append ''
  | str join (char nul)
  | ^/bin/sh -e -c r#'
    while IFS= read -r -d '' file; do
      . "$file";
    done
    /usr/bin/env -0
  '#
  | decode utf-8
  | split row (char nul)
  | parse "{key}={value}"
  | each {|row| { $row.key: $row.value } }
  | into record
  | reject --optional __NU_SCRIPT_PATH SHLVL PWD OLDPWD _ TERM
}

export def --env direnv_hook [] {
  let env_diff = direnv export json | from json
  if ($env_diff | is-empty) {
    return
  }

  mut hide = []
  mut load = {}
  for row in ($env_diff | transpose key value) {
    if $row.value == null {
      $hide = $hide | append $row.key
    } else {
      $load = $load | insert $row.key $row.value
    }
  }

  if ($load | is-not-empty) {
    $load | convert-env | load-env
  }

  for key in $hide {
    hide-env $key
  }
}

export def tilde-home [] {
  let input = $in
  match (do -i { $input | path relative-to $nu.home-path }) {
    null => $input
    '' => '~'
    $relative_pwd => ([~ $relative_pwd] | path join)
  }
}

export def short-dir [ --keep (-k): int = 3 ] {
  let segs = ($in | split row (char path_sep))

  let short = $segs | slice ..<(-1 * $keep) | each {|seg|
    let end = (if ($seg | str starts-with '.') { 2 } else { 1 })
    $seg | str substring 0..<$end
  }
  let long = $segs | slice (-1 * $keep)..

  $short ++ $long | str join (char path_sep)
}

export def color-path [seg_color: string, sep_color: string] {
  $"($seg_color)($in)(ansi reset)"
  | str replace --all (char path_sep) $"($sep_color)(char path_sep)($seg_color)"
}

export def greek-letter [] {
  match $in {
    "a" => "α"   # alpha
    "b" => "β"   # beta
    "c" => "χ"   # chi
    "d" => "δ"   # delta
    "e" => "ε"   # epsilon
    "f" => "φ"   # phi
    "g" => "γ"   # gamma
    "h" => "η"   # eta
    "i" => "ι"   # iota
    "j" => "j"   # no Greek, keep Latin
    "k" => "κ"   # kappa
    "l" => "λ"   # lambda
    "m" => "μ"   # mu
    "n" => "ν"   # nu
    "o" => "ω"   # omega
    "p" => "π"   # pi
    "q" => "θ"   # theta (convention)
    "r" => "ρ"   # rho
    "s" => "σ"   # sigma
    "t" => "τ"   # tau
    "u" => "υ"   # upsilon
    "v" => "ν"   # same as n
    "w" => "ω"   # omega
    "x" => "ξ"   # xi
    "y" => "ψ"   # psi
    "z" => "ζ"   # zeta
    $letter   => $letter  # default: keep unchanged
  }
}

export def clamp [lo:int, hi:int, x:int] {
    if $x < $lo {
        return $lo
    }
    if $x > $hi {
        return $hi
    }
    $x
}
