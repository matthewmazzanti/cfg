# CS2 / Source 2 stutter investigation — 2026-07-04

## Symptom

On `desktop`, Source 2 games (CS2; historically Dota 2) run smoothly at first
(hitting `fps_max 240`), then degrade after ~20–40 minutes of play: FPS drops
to ~150 and frame delivery turns jerky/skipping. Once started, the degradation
persists indefinitely; restarting the game clears it, though occasionally it
survives a restart. The same pattern occurred years earlier on a different
machine running bspwm/X11 — also ZFS, also AMD.

## Environment

- Ryzen 9 5900X, RDNA3 dGPU (dcn32, 16 GiB VRAM), 32 GiB RAM
- NixOS, kernel 7.0.13, Mesa 26.1.4 (RADV), OpenZFS 2.4 on root
- Plasma 6 Wayland, game in nested gamescope, dual 4K@60 monitors
- Launch line at end of session:
  `gamescope -W 3840 -H 2160 -r 60 --force-grab-cursor -f -- gamemoderun %command% -novid +fps_max 120`

## Hypotheses tested and eliminated

All measurements below were taken live over SSH *while the game was visibly
stuttering* (two sessions), mostly via `scripts/memwatch`.

| Hypothesis | Evidence against |
|---|---|
| ZFS ARC starving the game | ARC was effectively uncapped (`c_max` ≈ 30 GiB, OpenZFS 2.2+ default); capped to 8 GiB and verified pinned there. Stutter reproduced anyway with PSI memory 0.00 and 11–12 GiB available. Cap kept as good hygiene. |
| Swap-in hitches | Swap untouched (0 B used) throughout; `vm.swappiness=10` set anyway. |
| Thermal throttling | During stutter: GPU junction 59–76 °C, VRAM 66–82 °C (throttle ≈ 95–100 °C), CPU 56–71 °C, GPU fan ~570 rpm. Cool everywhere. |
| CPU clock sag | Cores boosting 4.6–4.7 GHz mid-stutter (amd-pstate-epp, performance governor). |
| CPU-bound game | Busiest CS2 thread at 29% of a core, render thread 19% (instantaneous, not lifetime averages). |
| GPU-bound game | GPU busy erratic (1–99% between samples) with sclk sagging — the GPU is *starved*, not saturated. |
| IO stalls | Global PSI io read 47%, but it was a kernel PSI accounting leak: ghostty's cgroup pinned at exactly 100.00% io pressure with zero threads in D state and the pool near-idle. Red herring; restart ghostty to clear the counter. |
| THP/compaction stalls | `compact_stall` delta zero during stutter; THP in `madvise` mode. |
| VRAM oversubscription | VRAM flat at ~8–9.2 GiB of 16.4 GiB across the whole degrading session; GTT spillover ~0.9–1.3 GiB and not climbing. Nothing evicting. |
| GPU faults/resets | Kernel log clean both boots — no OOM kills, ring timeouts, or GPU resets. |
| WM / compositor stack | Same symptom historically on bspwm/X11 without gamescope or KWin. |

Also noted: 150 FPS on a 60 Hz panel is a 2.5:1 ratio, whose uneven frame
cadence amplifies the *perceived* jerkiness once degraded — hence `+fps_max
120` (integer 2:1) — but pacing is a symptom amplifier, not the cause.

## Conclusion

Every externally visible resource is healthy while the game decays, and the
decay follows the process (reset by restart). The degradation is internal to
the CS2 native Vulkan renderer and/or RADV's per-process behavior. This is a
known, widely reported Source 2 on Linux issue:

- <https://github.com/ValveSoftware/csgo-osx-linux/issues/3808> — FPS decays
  per match on vulkan-radeon, recovers on restart; AMDVLK eliminated it
  (driver-implicated); closed "not planned"
- <https://github.com/ValveSoftware/csgo-osx-linux/issues/3498> — CS2 VRAM leak
- <https://github.com/ValveSoftware/Dota-2/issues/2113> — Dota 2 slow VRAM
  leak until crash (same engine)

Reproducing on Mesa 26.1.4 / kernel 7.0.13 (current as of this session) means
it is not fixed upstream. The AMDVLK workaround is gone: AMD deprecated AMDVLK
in Sept 2025 and nixpkgs removed it — RADV is the only AMD Vulkan driver now.

## Config changes made this session

- `zfs.zfs_arc_max` = 8 GiB kernel param, `vm.swappiness` = 10
- `kvm-intel` → `kvm-amd`, Intel → AMD microcode updates (stale from an old
  machine; microcode gap was real — kernel reported TSA vulnerable)
- GameMode enabled (renice 10, screensaver inhibit) + `gamemode` group
- `scripts/memwatch` — live monitor: RAM / ARC / PSI / CPU+GPU temps /
  GPU clock / fan / busy / VRAM / GTT

## Next steps

1. **Proton A/B test** (no config needed): force the Windows build via Steam →
   Properties → Compatibility. Swaps the native Vulkan renderer for
   D3D11→DXVK, a completely different allocation pattern on RADV. Smooth long
   session ⇒ native-renderer/RADV interaction convicted and a playable
   workaround exists.
2. Interim mitigation: restart the game every few matches, before the decay.
3. Report the elimination data upstream (issue #3808 or a fresh Mesa issue) —
   a fully-instrumented repro on current Mesa is a stronger data point than
   anything currently in the thread.
4. Cosmetic: restart ghostty on `desktop` to clear the stuck PSI counter.
