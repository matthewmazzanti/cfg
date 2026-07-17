# Working on the host-management scripts

These are **operational tooling, not part of the flake eval** — they build,
deploy, and maintain hosts, and they refresh the pinned data the flake reads.
`just` targets are thin wrappers over them (see the root `CLAUDE.md`).

Convention: **stdlib-only Python** (`hostctl`, `bump-kernel`, `generate-mac`) so
they run anywhere without a dev shell. The exception is `lock-images`, a
`uv run` script with an inline PEP-723 dependency block (it needs `httpx`).

## The scripts

- **`hostctl`** — the deploy engine, and the biggest thing here. One target axis
  (this machine, or a remote over ssh) × lifecycle verbs (`upgrade`/`deploy`,
  `clean`, `sync`, `gc-roots`). A target is a **flake config attr** (e.g.
  `desktop`) and defaults to this machine, so `hostctl clean` and `hostctl clean
  desktop` are the same code path with an ssh hop auto-inserted. **`SSH_HOSTS`**
  maps each attr → the ssh host it's reached at, used for ssh, `nix copy`, and
  building git URLs (there are no named git remotes). NixOS and darwin hosts are
  handled uniformly — each target's kind/system is read from the flake. Read the
  module docstring; it's the spec. See memory `nix-cfg-deploy-hostctl`.
  - **`gc-roots`** is the odd one out: local-only (this junk accumulates per
    workstation, not on servers), takes no host target, and is dry-run unless
    `--prune`. It unlinks the *targets* of auto gcroots matching `GC_ROOT_RULES`
    (nix-direnv links, `nix build` results) that we own and are older than
    `--older-than` days; the now-dangling `auto/<hash>` entries and freed store
    are reclaimed by the next `clean`. Rules are locked in the cmd layer for now,
    meant to become configurable. `GC_ROOT_RULES` is the seam.
- **`bump-kernel`** — advances the kernel + zfs pins in `../lib/pins.json`,
  **forward-only** (never a downgrade). It evals `.#lib.zfsKernelMatrix` (a pure
  projection defined in `../lib/`) for the candidate pairs and applies the
  *policy* (forward-only floor, prefer LTS, newest pair) here in Python. Run via
  `just update` after `nix flake update` so it lands as a reviewable diff.
- **`lock-images`** — resolves container image tags → pinned `@sha256:` digests
  in `../lib/images.json` (docker.io / ghcr.io / quay.io). The `ha` host reads
  these via `flake.lib.images`. Also run from `just update`.
- **`generate-mac`** — prints one locally-administered unicast MAC. Trivial
  helper for declaring a fixed container/interface MAC.

## Notes

- **`bump-kernel` and `lock-images` share a CLI shape**: `--json <file>` selects
  the pins/images file, `--write` overwrites it in place (atomically, via a temp
  file); without `--write` the resolved JSON is printed to stdout for inspection.
- These write into `../lib/*.json`, which the flake imports — so a run here is
  what feeds `flake.lib.pins` / `flake.lib.images`. Keep that direction in mind:
  scripts produce the pinned data, Nix consumes it.
