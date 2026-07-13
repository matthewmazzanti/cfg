# Working on the zsh config

A **wrapped zsh** — see `../CLAUDE.md` for the wrapper pattern. `default.nix`
assembles the runtime config, builds a `zdotdir` derivation, and the wrapper sets
`ZDOTDIR` to it. Nothing is read from `~/.zshrc`; the store path is authoritative.
`zshenv` sets `no_global_rcs`, so `/etc/zshrc` etc. are skipped — this config has
total control of the environment.

## How the config is assembled

`default.nix` builds `zshrc` as a string that `source`s each `config/*.zsh` in a
**fixed, order-sensitive sequence**:

```
base-env → completion → plugins → lib → fzf → jumplist → clip → prompt → init
```

Order matters and is finicky (there's a standing TODO about it): later files use
ZLE widgets and functions defined by earlier ones. **`init.zsh` is last** because
its keybindings reference `clip_widget`, the fzf widgets, and the jumplist
widgets defined upstream. If you add a `config/*.zsh`, insert it at the right
point in that list in `default.nix` — dropping the file in the dir does nothing
on its own (and remember to `git add` it, or the build won't see it).

## Plugins come in as store paths, not runtime fetches

`default.nix` passes plugins to the config through a `NIX_INPUTS` associative
array (fast-syntax-highlighting theme + plugin, autosuggestions), which
`plugins.zsh` reads and then `default.nix` `unset`s. Two build-time tricks worth
knowing before you touch `default.nix`:

- **fast-syntax-highlighting is patched** — its "is `$FAST_WORK_DIR` writable"
  test is forced false so it can't override our theme dir. The **theme is
  prebuilt at build time** into a derivation (`fshTheme`) by running `fast-theme`
  in a sandbox against `config/fsh-colors.ini`. `chroma-man` highlighting is
  disabled (it's very slow).
- **autosuggestions' auto-start is dismantled and redone by hand** — its default
  `precmd` hook is removed and `_zsh_autosuggest_start` called manually, so the
  suggestion widget nests *under* the clip copy-wrapper instead of fighting it.
  Don't "simplify" this back to the stock init.

## clip.zsh — the ZLE clipboard layer (the delicate part)

`clip.zsh` is a self-contained, MIT-licensed reusable module that rewires the vi
operators so editing doesn't clobber the system clipboard:

- `c` / `d` / `s` (change/delete/substitute) → **blackhole** (discarded).
- `x` / `y` → **system copy**; `p` → **system paste**.
- `clip_widget <backend> <base-widget>` builds a wrapped ZLE widget; backends are
  `clip_copy` / `clip_paste` (defined elsewhere, overridable before sourcing).

`init.zsh` is where these get bound (`bindkey ... "$(clip_widget ...)"`). If a
yank/paste/delete starts behaving oddly, it's the interaction between this
wrapper and the autosuggestions/fsh widgets — that layering is the whole reason
the source order and the manual autosuggest init exist.

## Other notes

- **Vi mode with emacs-movement overlays** (`^A/^E/^F/^B/^P/^N` in both maps),
  `KEYTIMEOUT=1` for a fast insert→command escape. Jumplist (`^O`/`^I`,
  neovim-style dir history) lives in `jumplist.zsh`.
- **User escape hatch:** `init.zsh` sources `$XDG_CONFIG_HOME/zsh/zshrc` last if
  present — machine-local overrides that shouldn't be baked into the store.
- **Some files carry upstream MIT headers** (`fzf.zsh` from junegunn,
  `clip.zsh`) — preserve them when editing.
- **Login-shell wiring** is in `modules/nixos/zsh.nix` (via `passthru.shellPath`,
  so the store path isn't hard-coded in `/etc/passwd`), not here.
- Build + try: `nix build '.#"zsh/dev"' --print-out-paths` then run `$out/bin/zsh`.
