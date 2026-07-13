# Working on the custom packages

These build **custom-configured versions of upstream tools as store paths** —
the config is baked in, nothing is read from `$HOME` at runtime. `pkgs/default.nix`
is the registry: it `callPackage`s each subdir and names the result
`"tool/variant"` (e.g. `"zsh/dev"`, `"less/dev"`, `"nvim/dev"`,
`"ghostty/config"`). Those names surface as flake `packages.<system>.<name>` and
are consumed via `flake.packages."tool/variant"` from hosts/home configs.

Build any one directly:

```sh
nix build '.#"zsh/dev"' --no-link --print-out-paths   # binary/config at $out
```

## The wrapped-config approach

Most packages here follow the **same wrapper pattern** — learn it once and
`less`, `zsh` all read the same way. It exists so config travels in the
closure as a store path, not as a dotfile the tool hunts for in `$HOME`.

The shape (see `less/wrapper.nix`, `zsh/wrapper.nix`):

1. A `wrapper.nix` exposes `lib.makeOverridable wrapper`. It `symlinkJoin`s the
   upstream package, then in `postBuild`:
   - moves the real binary `bin/foo` → `bin/foo-unwrapped`, and
   - `makeWrapper`s a fresh `bin/foo` that injects the config as a **flag or env
     var** pointing at a store path:
     - `less` → `--lesskey-src=${lesskeyDrv}` (+ default flags)
     - `zsh` → `--set ZDOTDIR ${zdotdir}` (a derivation holding `.zshrc`/`.zshenv`)
2. A `default.nix` (or `dev.nix`) supplies the tool + the config, read from disk
   with `builtins.readFile ./foo.conf`, and calls the wrapper.

Because the wrapper is `makeOverridable`, a consumer can
`(pkgs."tool/dev").override { conf = ...; }` to reconfigure without forking.

**Two shapes exist — don't assume everything is a wrapped binary:**

- **Wrapped binary** — `less`, `zsh`, `nvim`. Produces a runnable
  `$out/bin/<tool>` with config baked in.
- **Generated config file** — `ghostty`. `ghostty/default.nix` produces a
  `writeText` config file (rendered from a Nix attrset via `ghostty/format.nix`,
  with per-platform darwin/linux branches), *not* a binary. It's consumed as a
  file source: `home.file.".config/ghostty/config".source =
  flake.packages."ghostty/config"`. Ghostty itself comes from its own flake input.

## Consumers

- **home configs** — `sys/*/home.nix` (home-manager `home.file.*.source` or
  `home.packages`).
- **host configs** — `sys/*/default.nix` (`environment.systemPackages`,
  `users.users.<u>.packages`).
- **as a login shell** — `zsh/dev` is wired in `modules/nixos/zsh.nix` through
  `passthru.shellPath` (so the `/nix/store` path isn't hard-coded into
  `/etc/passwd`).

## Gotchas

- **Git-tracked files only.** A new `config/*.zsh`, `plugin/*.lua`, or `.conf`
  is invisible to the build until `git add`ed — `require`/`source` silently
  fails or the setting no-ops. Stage new files (uncommitted is fine) before
  building. This is the single most common way a change "doesn't apply."
- `nvim` and `zsh` have their own `CLAUDE.md` — read those before editing them.
