# Working on this Nix config

A single flake that builds **everything**: NixOS + nix-darwin hosts, standalone
home-manager configs, and a set of custom-wrapped CLI packages. There's no
dotfiles-on-disk anywhere — configs are baked into store paths and activated, so
**every change needs a build + activate** before it takes effect.

This file is the hub: repo-wide topology and the gotchas that cross module
boundaries. Subtrees with their own machinery carry a nested `CLAUDE.md`
(`sys/`, `sys/ha/`, `pkgs/`, `pkgs/zsh/`, `pkgs/nvim/`) — read those before
working inside them; they assume what's here.

## Topology

`flake.nix` wires five things, each a directory you can read in isolation:

- **`lib/`** → `self.lib`. Factories + pinned data (`eachSystem`, `keys`,
  `images` from `images.json`, kernel/zfs `pins` from `pins.json`). Pure, no host
  eval.
- **`sys/`** → `nixosConfigurations` / `darwinConfigurations` / `homeConfigurations`.
  One directory per host; `sys/default.nix` is the registry. See `sys/CLAUDE.md`.
- **`pkgs/`** → `packages.<system>`. Custom-configured tools (nvim, zsh, less,
  ghostty) built as store paths. See `pkgs/CLAUDE.md`.
- **`modules/nixos/`** → `nixosModules` (`base`, `impermanence`, `lanzaboote`,
  `zsh`). Reusable, host-agnostic building blocks that hosts `import`. Keep
  `base.nix` host-agnostic — host specifics belong in the host dir.
- **`bin/`** — host-management scripts (`hostctl` is the deploy engine). Stdlib
  Python / shell, not part of the flake eval. See memory + `bin/hostctl --help`.

## The `flake` specialArg — the one wiring fact to know

Every host and home module receives `flake` via `specialArgs`/`extraSpecialArgs`
(assembled in `sys/default.nix`):

```nix
flake = { inputs; packages; lib; modules; }
```

That's how a module reaches across the tree without `import` paths:

```nix
{ flake, ... }: {
  imports = [ flake.modules.base ];                 # nixosModules
  users.users.mmazzanti.packages = [ flake.packages."nvim/nix" ];
  # flake.lib.images.hass, flake.inputs.switchbot-ble, ...
}
```

If you're threading a package/module/input into a host, it comes through
`flake.*`, never a relative path into `../../pkgs`.

## Deploy / activate

`just` wraps `bin/hostctl` (target = a flake attr like `desktop`; **no target =
this machine**):

```sh
just upgrade <host>   # build locally, copy the closure, activate (default for remotes);
                      # --build-on-host to build on the target instead
just clean  <host>    # GC old generations + prune boot entries
just update           # nix flake update + refresh images.json + bump kernel pins
```

`hostctl` builds git URLs from `SSH_HOSTS` — there are no named git remotes. See
memory (`nix-cfg-deploy-hostctl`) and the module docstring in `bin/hostctl`.

## Cross-cutting gotchas

- **Flakes only see git-tracked files.** A new `.nix`/`.lua`/`.zsh`/config file
  is invisible to the build until `git add`ed — the feature silently no-ops with
  no error. Staging (uncommitted) is enough. This bites in every subtree.
- **The "Git tree is dirty" warning is fine.** Working-tree edits to *tracked*
  files are included in the build.
- **Nothing is read from `$HOME` at runtime.** Editing a file under `~/.config`
  does nothing — the store path is authoritative. Rebuild to see a change.
- **Format with `alejandra`** (in the devShell, alongside `nix-tree`, `uv`,
  `just`). `nix develop` / direnv provides them.
