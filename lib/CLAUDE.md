# Working on the flake lib

`import ./lib nixpkgs` → `self.lib`: the flake's shared helpers and pinned data.
Everything here is **pure** (no host eval) and reachable from any module as
`flake.lib.*` (see the root `CLAUDE.md` for the `flake` specialArg). `default.nix`
is the surface; the rest are one-file factories or data.

## What's exposed

- **`eachSystem` / `eachSystemShell`** — map a function over the supported
  systems into an attrset keyed by system. The backbone of `packages` and
  `devShell` in `flake.nix`.
- **`keys`** (`keys/default.nix`) — SSH pubkeys + the CA cert, `readFile`d from
  `keys/` so hosts reference them as `flake.lib.keys.ssh.<host>` /
  `keys.ca.crt` instead of pasting key material.
- **`images`** — `images.json` parsed via `importJSON`. Container digests,
  written by `bin/lock-images`. Read by `sys/ha` as `flake.lib.images.<name>`.
- **`pins`** — `pins.json`, the kernel + zfs package-attr pins. Written
  **forward-only** by `bin/bump-kernel`; read by `base.nix` as `flake.lib.pins`.
- **`zfsKernelMatrix`** (`zfs-kernel-matrix.nix`) — a **pure projection** of the
  zfs × linux compatibility matrix for a nixpkgs (rows whose zfs module isn't
  `meta.broken`, with versions). **No policy lives here** — the floor / "newest"
  / prefer-LTS logic is all in `bin/bump-kernel`, which consumes this. Keep that
  split: this file only reports what nixpkgs offers.
- **`zfsImportAfterLuks`** (`zfsImportAfterLuks.nix`) — a factory returning a
  `systemd.services` fragment that orders each ZFS boot pool's import after its
  backing LUKS devices unlock (a dep the NixOS zfs module doesn't wire). Called
  from a host's `hardware.nix`.

## Notes

- **The JSON files are generated, not hand-edited.** `images.json` ←
  `bin/lock-images`, `pins.json` ← `bin/bump-kernel` (both via `just update`).
  Edit the scripts/policy, not the JSON, unless you're doing a deliberate manual
  pin.
- **`escapeSystemdPath` trick** (top of `default.nix`): it's pulled from
  `nixpkgs/nixos/lib/utils.nix` with throwaway `config`/`pkgs` — the helper only
  touches `lib` and Nix is lazy, so this borrows the canonical function without a
  NixOS eval. Don't "clean up" the empty `config = {}; pkgs = {};`.
- **`zfsKernelMatrix` evals for every system** but is only meaningfully read for
  the linux host `bump-kernel` runs on; the projection is guarded (`tryEval` per
  kernel attr) so a removed/EOL attr contributes nothing rather than aborting.
- `mkNakedShell.nix` backs `eachSystemShell` — a minimal `nix develop` stdenv;
  the `builder` must be bash (noted inline).
