# Working on the Home Assistant host

The most intricate host in the tree. It runs Home Assistant, a Z-Wave JS
controller, and an nginx TLS terminator as **rootless podman containers** wired
through `quadlet-nix` (`flake.modules.quadlet`). Almost everything of interest is
in `home-automation.nix`; `default.nix` is the thin host shell.

## Container topology (read this before touching networking)

`overview.md` at the repo root is **stale** (it describes a two-network
bridge+macvlan design that no longer exists). The live layout, from
`home-automation.nix`:

- **One pod `ha`** on a **single macvlan network** (`172.18.0.0/16`, pod IP
  `172.18.2.11`, fixed MAC). All three containers share the pod's network
  namespace.
- Because they share a netns, **containers reach each other on `127.0.0.1`** —
  `nginx.conf` proxies to `127.0.0.1:8123` (hass) and `127.0.0.1:8091` (zwave),
  *not* to container names.
- **nginx** terminates TLS on `:443` for `hass.iot` / `zwave.iot` (certs live in
  `/var/lib/nginx/ssl`, **not in the repo**). Ports 80/443 are the only ones
  open on the host.
- State is on dedicated ZFS datasets (`/var/lib/{nginx,hass,zwave}`);
  `/var/lib/containers` is persisted via impermanence.

## Images

Container images are pinned in `flake.lib.images` (`lib/images.json`, refreshed
by `bin/lock-images` / `just update`) — referenced as `flake.lib.images.<name>`.
All three containers (nginx, hass, zwave) pull their pinned image directly.

> Historical note: hass used to run a local override image (`builds.hass`) that
> injected a git `pyatv` into the Apple TV manifest, a workaround for the tvOS
> 26.4 power-state regression. Dropped once hass stable shipped pyatv 0.18.0
> (HA 2026.7.0), which carries the fix natively.

## Config files are mounted read-only from the store

The containers get their config by bind-mounting store paths in as `:ro`
volumes (so a change means rebuild + activate, never an edit inside the
container):

- `configuration.yaml` → `/config/configuration.yaml`
- `macros.jinja` → Jinja custom templates
- `multicast_exec/` → `/config/custom_components/multicast_exec` (see below)
- `switchbot` custom component comes from `flake.inputs.switchbot-ble`

## multicast_exec — the local custom integration

A hand-written HA integration (Python, `multicast.py` + `manifest.json`) mounted
as a custom component. It exposes the `multicast_exec.set` / `multicast_exec.toggle`
actions used throughout `configuration.yaml` automations (it batches set/toggle
across zwave + other entities). Edit the `.py`; changes need a container restart
(rebuild + activate the host). `README.md` is intentionally empty — this file is
the doc. `manifest.json` still carries placeholder `codeowners`/`documentation`.

## Lovelace dashboard — seed vs live edits

The dashboard has two sources of truth and the **seed wins on restart**:

- `ui-lovelace.yaml` is the committed baseline. `hass-lovelace-seed` (a oneshot,
  `PartOf`/`before` `hass.service`) bakes it into `.storage/lovelace.lovelace`
  before HA starts. A `systemctl restart hass` re-applies it, **discarding any
  live UI/API edits**.
- `just push-ui` / `just pull-ui` (via `scripts/lovelace.py`, HA websocket API)
  edit the *live* dashboard without a restart. Use `pull-ui` to capture live
  tweaks back into the YAML, then **commit to persist** — otherwise the next
  restart/rebuild resets to the baseline.

## Other

- **zwave** passes through a USB serial device
  (`/dev/serial/by-id/usb-Nabu_Casa_ZWA-2_...`) and reads secrets from
  `/var/lib/zwave/env.secret` (not in the repo).
- Containers run hardened: dropped caps, `noNewPrivileges`, minimal added caps
  per service — preserve that when adding a container.
