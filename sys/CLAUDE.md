# Working on the host configs

One directory per machine. `default.nix` is the **registry** — it turns each
host dir into a `nixosSystem` / `darwinSystem` / `homeManagerConfiguration` and
injects the `flake` specialArg (see the root `CLAUDE.md` for what `flake`
contains). NixOS and darwin hosts are handled uniformly; only the constructor
differs.

## Per-host directory convention

A host dir (`desktop/`, `framework/`, `ha/`, `server/`, `beta/`, …) holds some of:

- **`default.nix`** — the system config. Composes reusable modules + local
  hardware: `imports = [ flake.modules.base flake.modules.impermanence
  flake.modules.lanzaboote ./hardware.nix ];` then host-specific bits
  (`networking.hostName`, `hostId`, packages, services).
- **`home.nix`** — a **standalone** home-manager config, *not* a NixOS
  home-manager module. It's registered separately in `default.nix` as
  `home."user@host"` and deployed on its own axis (`hostctl --only hm|sys`). A
  host can exist with no `home.nix`.
- **`hardware.nix`** — disk/filesystem/kernel/firmware for that box.
- **`scripts/{install,partition}.sh`** — one-time bare-metal provisioning
  (partition the disks, install). Not run on rebuilds.

## Adding a host

1. Create `sys/<name>/` with at least `default.nix` (+ `hardware.nix`).
2. Register it in `sys/default.nix` — pick `nixosSystem`/`darwinSystem`, set
   `modules = [ ./<name> ]` and `specialArgs.flake = flakeArgs.${system}`.
   Add a matching `home."user@<name>"` block if it has a `home.nix`.
3. `git add` the new dir (flakes ignore untracked files) before building.

## Notes

- **Systems are pinned per constructor** in `default.nix`: linux is
  `x86_64-linux`, darwin is `aarch64-darwin`. `systemPkgs` is built once per
  system with `allowUnfree`.
- **`base.nix` is host-agnostic** — resist pushing a one-host tweak into it;
  that's what the host dir is for (see memory `nix-cfg-dry-shared-modules`).
  Lean on `flake.lib` factories for genuinely shared per-host derivation, but
  it's a lean, not a rule.
- **`sys/ha` is the intricate one** (podman containers, custom HA integration,
  macvlan networking) and has its own `CLAUDE.md`.
