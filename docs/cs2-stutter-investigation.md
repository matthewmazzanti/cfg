# CS2 / Source 2 stutter investigation — 2026-07-04

## Symptom

On `desktop`, Source 2 games (CS2; historically Dota 2) run smoothly at first
(hitting `fps_max 240`), then degrade after ~20–40 minutes of play: FPS drops
to ~150 and frame delivery turns jerky/skipping. Once started, the degradation
persists indefinitely; restarting the game clears it, though occasionally it
survives a restart. The same pattern occurred years earlier under bspwm/X11 with
an RX 580 (Polaris). Critically, this is the **same physical machine** — same
Ryzen 9 5900X, same motherboard, same RAM, same ZFS root — across both eras; the
**only hardware that changed is the GPU** (Polaris → RDNA3), plus the WM
(bspwm/X11 → Plasma) in software. So every non-GPU hardware factor (CPU, dual-CCD
topology, board, memory subsystem, PCIe) is a hard constant, and the GPU
architecture is provably *not* the invariant.

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

## Session 2 — 2026-07-05: MangoHud instrumentation + cross-game triangulation

Headless MangoHud frametime logging (100 ms samples) alongside memwatch, one
28-min session. New, decisive evidence:

- **Sharp onset at 25.1 min.** Frametime baseline ~4.6 ms (≈217 fps equiv on a
  60 Hz cap — the GPU is massively over-provisioned). At t=1508 s it flips to a
  steady train of ~45 ms spikes (≈2.7 missed vblanks) recurring every few
  seconds to session end. Both logs agree on the wall-clock minute.
- **Post-onset the GPU is asked to do *less*:** MangoHud gpu_load 71→48 %,
  power 110→90 W, clock 2025→1850 MHz. "Starved, not saturated" — now measured.
- **The spike frames are not GPU-bound and not clock-starved.** At 100 ms
  resolution the 45 ms frames sit at 49 % load / 1814 MHz — identical to the
  4 ms frames around them. A 45 ms frame while the GPU is clocked at 1.8 GHz and
  half-idle was *blocked*, not computing. (The idle-clock dips memwatch's coarse
  5 s sampling caught are the *gaps between* stalls, not the stalls — this
  corrects the first-pass "hitch = downclock" read.) CS2's render loop is
  periodically blocking internally; the downclock is downstream of that.
- **Reproduces without gamescope and without gamemoderun.** Removes 4.4 (nested
  compositor) and 5.5 as necessary conditions.
- **Bare-config note (2026-07-06): no MangoHud / no gamescope / no gamemode.**
  Removing gamescope *raises* baseline frametime (~4 → ~6 ms as read on the
  built-in counter; ~220 fps, just off the 240 cap) — counter-intuitive for
  dropping a layer, but consistent with gamescope owning the swapchain and pacing
  cs2 in immediate/mailbox, decoupling it from KWin's compositor; direct-to-KWin
  costs ~a couple ms/present and no longer pins the cap. Baseline throughput only
  — does NOT change the decay (reproduces here too), and this bare path is the
  cleanest repro (fewest layers). Caveat: no MangoHud → memwatch GAME_FPS goes
  dark (read cs2 built-in cl_showfps/net_graph instead); scripts/stutter-capture
  is unaffected (it uses perf/ftrace, not the CSV).
- **Arc Raiders (UE5, Proton→vkd3d→RADV) runs smooth for hours on the identical
  GPU / RADV / kernel / KWin / DP / KVM / ZFS stack.** A heavy game hammering the
  same display + present path is fine. With the historical bspwm/X11 repro (no
  KWin, no gamescope), this eliminates the entire display / present / KVM branch
  (4.4, 7.x) as the cause.

Cross-machine constants, refined by the RX 580 revelation: the **same 5900X drove
both GPUs**, and the GPU architecture *changed* (Polaris → RDNA3) while the bug
survived — so it is NOT GPU-silicon-specific (matches the cross-generation reports:
Polaris here, RDNA2 #398, RDNA3 #3808). What stayed constant across both eras:
the 5900X (dual-CCD), RADV/Mesa Vulkan, Source 2 native Vulkan, ZFS, Linux. Arc
Raiders (RDNA3, RADV, ZFS, same CPU, but UE5/vkd3d — *not* Source 2 native Vulkan)
is smooth, which points at the Source-2-native-on-AMD interaction rather than any
single component.

Three survivors remain, cut by two cheap one-knob tests:
- **2.4 cross-CCD sync latency** (CPU is the hardest constant) → `taskset` single-CCD.
- **4.1 RADV per-process decay** on CS2's native path → Proton A/B (DXVK is a
  different RADV path; Arc Raiders proves it's smooth here). Matches #3808 (AMDVLK
  was immune; RADV decays per match, restart resets).
- **6.1 Source 2 renderer state accumulation** → the residual if both tests come
  back clean; API- and CPU-topology-independent, i.e. a pure Valve engine bug.

**Verdict leaning: Source 2 busted on AMD** — most likely its native-Vulkan/RADV
path, with dual-CCD latency as a live co-suspect now that the CPU is the strongest
invariant. The taskset and Proton sessions decide between the three.

GPU-DPM sidebar (dead end): `power_dpm_force_performance_level=high` is a
**confirmed no-op** on this Navi32 / kernel 6.18 — with `high` forced the core
clock still idles to 6 MHz. `pp_dpm_sclk` is a read-only SMU readout (write →
EINVAL); overdrive is off (ppfeaturemask 0xfff7bfff, no `pp_od_clk_voltage`), so
runtime clock pinning would need `amdgpu.ppfeaturemask=0xffffffff` + reboot. Not
pursued: the clock follows CS2's (absent) work — it isn't fighting it.

## Root-cause taxonomy

Status: ✗ eliminated · ⚑ leading suspect · ? open

**1. Hardware / firmware**
- 1.1 CPU thermal throttling — ✗ 56–71 °C during stutter, boosting 4.6–4.7 GHz
- 1.2 GPU core thermal throttle — ✗ junction 59–76 °C vs ~110 limit
- 1.3 VRAM (GDDR6) thermal throttle — ✗ 66–82 °C vs ~95–100 limit
- 1.4 Power/current limits (PROCHOT, SMU caps) — ✗ clocks stay high; decay follows process, not silicon
- 1.5 Failing hardware (NVMe, RAM, PCIe) — ✗ but NOT by "different machines": it's the
  SAME board/CPU/RAM across both eras, so that pillar is void (corrected 2026-07-05).
  Held ✗ on other grounds: decay is per-process and resets on game restart (a hardware
  fault isn't process-scoped), Arc Raiders runs hours-stable on the same RAM/PCIe, and
  journals are clean (no MCE/EDAC/PCIe-AER). Cheap insurance if ever doubted: memtest +
  `journalctl -k | grep -iE "mce|edac|aer"`.

**2. Kernel**
- 2.1 Memory pressure / reclaim stalls — ✗ PSI mem 0.00, 11+ GB available during stutter
- 2.2 THP/compaction stalls — ✗ zero compact_stall, madvise mode
- 2.3 IO stalls — ✗ PSI io 47% was a stuck-counter accounting leak (ghostty cgroup); pool near-idle
- 2.4 Scheduler contention / cross-CCD sync latency — ⚑ REOPENED 2026-07-05. Two
  parts: (a) runqueue/preemption starvation — ✗ GAME_WAIT stayed low (5–26 ms) and
  CTXT_K *dropped* post-onset, so threads aren't sitting runnable-waiting-for-a-core
  (earlier "GAME_WAIT ~490 ms" was a column misread — that was GAME_FPS). (b) cross-CCD
  memory latency — ⚑ the 5900X is dual-CCD (CCD0 cores 0–5 / CCD1 6–11); cross-CCD
  syncs hop the IOD at ~2–3× intra-CCD latency and show up as *run-time* stalls,
  invisible to schedstat wait. Source 2's fine-grained job-system sync is exactly
  what that punishes, and the SAME 5900X is the hardest cross-machine constant (drove
  both the RX 580 and the RDNA3 card). Caveats: Arc Raiders is smooth on this CPU, and
  the 25-min onset is time-dependent while topology is static — so if real it's an
  *interaction* (accumulating Source 2/RADV state tipping cross-CCD sync over), not the
  sole cause. Test: `taskset -c 0-5,12-17` single-CCD session (runbook queue A).
- 2.5 IRQ storms / lock contention — ? unlikely; CTXT_K column watches it
- 2.6 Kernel-side leak (ZFS, DRM slab) — ? unlikely; SLAB_MB column watches it
- 2.7 TLB-shootdown / IPI storm — ? NEW (surfaced by the tracing plan, 2026-07-06).
  Frequent memory remapping (engine or RADV) floods cross-core TLB-invalidation IPIs;
  on the 5900X the cross-CCD ones are the expensive path, so this is the burst-of-tiny-
  stalls route AND bridges to 2.4. Invisible to every level-monitor so far. Watch:
  `perf stat -e tlb_flush`, bpftrace on `smp_call_function`, gpuvis irq_vectors.
- 2.8 C-state exit latency / PM-QoS — ? NEW, LOW credibility for this magnitude. CPU
  idles ~11 ms/frame at the 60 Hz cap, then pays wake latency; explains sub-ms jitter,
  not a 45 ms spike. Cheap knock-out if ever suspected: write 0 to /dev/cpu_dma_latency.

**3. Storage / ZFS**
- 3.1 ARC starving the game — ✗ capped to 8 GiB, stutter reproduced with pressure zero
- 3.2 ARC eviction contention at cap — ✗ mild counters, no throttling; live shrink-test
  (`echo $((4*1024*1024*1024)) | sudo tee /sys/module/zfs/parameters/zfs_arc_max`) never
  run — revive only if GAME_MAJF lights up
- 3.3 txg sync / write stalls — ✗ near-zero writes during play; DIRTY_MB watches

**4. Graphics stack (host side)**
- 4.1 RADV per-process decay (allocator/descriptor churn) — ⚑ matches #3808 exactly:
  per-match decay, restart resets, AMDVLK was immune; reproduces on Mesa 26.1.4.
  NEW sub-mechanisms the tracing plan can now name (2026-07-06), leak-free (RSS flat):
  (a) allocator fragmentation / suballocator slow-path — RMV; (b) a hot RADV/Mesa
  mutex serializing the render thread (lock convoy) — offcputime→futex; (c) growing
  submission chains / barriers — gpuvis. These were invisible to level-monitoring.
- 4.2 amdgpu kernel driver faults/resets — ✗ journal clean both boots
- 4.3 VRAM oversubscription / BO eviction thrash — ✗ VRAM flat at ~9/16.4 GB during decay
- 4.4 Presentation path (gamescope nesting, KWin, 60 Hz pacing) — ✗ reproduced on
  bspwm/X11 AND without gamescope now; Arc Raiders smooth on the same KWin/DP path;
  150 fps on 60 Hz (2.5:1) amplifies perceived jerkiness only

**5. Steam layer**
- 5.1 In-game overlay (gameoverlayrenderer.so + steamwebhelper state) — ✗ Arc Raiders
  runs with the same overlay/webhelper preload hooking every present and stays smooth;
  if the overlay were the cause it would decay too. (Was the "survives restart" theory.)
- 5.2 Background downloads/updates — ✗ timeline: client self-update pre-session only
- 5.3 Fossilize shader jobs — ✗ session boundaries only
- 5.4 NixOS FHS env / pressure-vessel — ✗ reproduces on Arch stock runtime; no
  accumulating mechanism; Proton test re-confirms for free
- 5.5 GameMode side effects — ✗ can't reach cs2 in-container; activity only at
  boundaries; reaper crash was exit-time cosmetic

Reported history (LOW CONFIDENCE, 2026-07-05): user recalls the stutter beginning
"long after" switching Dota 2 to the Vulkan renderer — i.e. onset in the Vulkan era,
not the OpenGL (radeonsi) era. Consistent with every external report being
Vulkan-on-AMD and with the RADV weighting (4.1/6.1). NOT directly testable: Valve
removed the OpenGL path from Dota 2 in March 2023 and CS2 never had it, so a GL-vs-
Vulkan A/B is impossible. Note it doesn't clear 2.4 either — Vulkan's multithreaded
submission raises cross-thread (hence cross-CCD) traffic vs GL's single-threaded
path, so the Vulkan switch could equally be what *exposed* the CCD latency. taskset
separates the two; Proton is the only remaining driver-path swap (GL/AMDVLK both gone).

**6. Game (CS2/Source 2 internal)**
- 6.1 Native Vulkan renderer state accumulation — ⚑ Valve closed #3808 "not planned";
  indistinguishable from 4.1 without the Proton test
- 6.2 System-RAM leak per match — ? reported upstream (#3925); GAME_RSS decides
- 6.3 fd/thread leak — ? cheap to watch; GAME_FD / GAME_THR columns
- 6.4 Fonts/Panorama UI thrash — ✗ launch-time parse noise; cache healthy; decay not
  UI-correlated

**7. Display / input path (DP 1.2 KVM between machine and monitor) — ✗ ELIMINATED
2026-07-05.** Backpressure mechanism reconsidered and rejected: DP scanout timing is
generated source-side by the display controller; a marginal sink fails loudly
(link-training / HPD / underflow, all leaving dmesg traces — journals clean), not as
silent per-vblank backpressure. Decisive: Arc Raiders runs smooth through the same
KWin → DP → KVM path, and the stutter reproduced historically on bspwm/X11 with no
part of this display stack. The whole branch is downstream, not causal.
- 7.1 DP link through KVM — ✗ same path smooth for Arc Raiders; no link/HPD events.
- 7.2 USB input path through KVM hub — ✗ display-side eliminated; input jitter, if
  any, is a separate perceptual issue, not the measured frametime decay.
- 7.3 Monitor itself — ✗ smooth for other titles on the same monitor.

Most of layers 1–5 and 7 are cleared by measurement + cross-game/cross-stack
triangulation. **Three** survivors remain (see the Session 2 synthesis above):
**2.4** cross-CCD sync latency (the 5900X is the hardest constant — same CPU, both
GPUs), **4.1** RADV per-process decay on CS2's native Vulkan usage, and **6.1**
Source 2 renderer state accumulation. Two one-knob tests cut them: `taskset`
single-CCD isolates 2.4; Proton A/B isolates 4.1 (DXVK is a different RADV path,
smooth for Arc Raiders here). If both come back clean, the residual is 6.1 — a pure
Source 2 engine bug, independent of graphics API and CPU topology.

## memwatch column legend

`scripts/memwatch` (run on desktop, or `ssh desktop.lan 'bash -s' <
scripts/memwatch | tee memlog.txt`). Drop a marker row while playing with
`echo "stutter start" > /tmp/memwatch.mark`.

```
TIME        sample wall-clock (5s interval default); MARK rows via /tmp/memwatch.mark
AVAIL_MB    MemAvailable — RAM the kernel could give out without swapping
ARC_MB      ZFS ARC size (capped at 8192 on desktop; pinned there is normal under load)
PSI         memory pressure some avg10 (%); >1.0 sustained = real memory stalls
CPU_C       CPU temp, k10temp Tctl (5900X throttles ~90C)
GPU_J       GPU junction temp (throttle ~110C)
GPU_MEM     VRAM/GDDR6 temp (throttle ~95-100C — least headroom in the box)
SCLK_MHZ    current GPU core clock (7800 XT game clock ~2100+; sagging w/ high BUSY = throttling)
FAN         GPU fan rpm
BUSY        GPU utilization % (erratic swings during play = GPU starved, not loaded)
VRAM_MB     card-wide VRAM used (16368 total; near-total + GTT climbing = oversubscription)
GTT_MB      GPU buffers spilled into system RAM over PCIe
GAME_RSS    game process resident RAM, MB (monotonic climb across maps = game-side leak)
GAME_VRAM   game process VRAM from fdinfo, MB (same, GPU-side)
GAME_FD     game open file descriptors (steady climb = fd leak)
GAME_THR    game thread count
WEBHLP_RSS  all steamwebhelper processes' RAM, MB (growth surviving game restarts = overlay suspect)
DIRTY_MB    dirty pages awaiting writeback (bursts = write stalls)
SLAB_MB     unreclaimable kernel memory (session-long climb = kernel-side leak: ZFS/DRM)
CTXT_K      context switches, thousands/sec (baseline ~35; sustained multiples = IRQ storm/thrash)
GAME_MAJF   game major page faults this interval (>0 during play = re-reading mapped data from disk)
GAME_WAIT   ms game main thread spent runnable-but-waiting-for-CPU this interval
            (spikes during stutter = scheduler contention; flat = game blocking internally)

'-' = not applicable (no game running / first sample for delta columns)
Baselines 2026-07-04, session start: GAME_RSS ~5300, GAME_VRAM ~5700, GAME_FD ~630,
GAME_THR 78, WEBHLP_RSS ~1400, VRAM_MB ~9000 in-game, CTXT_K ~35, GAME_WAIT ~0-1
```

## Next steps

Two cheap one-knob tests remain, run each as its own MangoHud-logged session with
`-condebug -conclearlog` so onset time + frametime signature compare directly to
the native baseline. Everything else is eliminated.

1. **Single-CCD pin (do this first — the CPU is the hardest constant).** Prepend
   `taskset -c 0-5,12-17 %command%` (CCD0 on the 5900X). Affinity inherits through
   pressure-vessel.
   - Stutter gone / onset pushed way out → cross-CCD sync latency (2.4); persistent
     fix is affinity via gamemode `[cpu]` pinning or a systemd slice, no BIOS
     CCD-disable needed.
   - Same ~25-min decay on one CCD → CPU topology exonerated; go to test 2.
2. **Proton A/B.** Steam → CS2 → Properties → Compatibility → force a Proton
   version. Swaps native Vulkan for D3D11→DXVK→RADV — the pattern Arc Raiders runs
   smooth on this box.
   - Smooth → convicts CS2's native Vulkan path (4.1); **Proton is the daily-driver
     workaround** (modern equivalent of the AMDVLK escape hatch from #3808).
   - Still stutters → residual is 6.1, a pure Source 2 engine bug, API- and
     CPU-topology-independent.
3. Interim mitigation: restart CS2 every few matches, before the ~25-min decay.
4. Report upstream (issue #3808 or a fresh Mesa RADV issue): a fully instrumented
   native-vs-Proton A/B (+ the single-CCD result) on current Mesa 26.1.4 is a
   stronger data point than anything in the thread — the MangoHud "45 ms frames at
   full clock, half GPU load" trace pins it as an internal render-loop/sync stall,
   not a memory or display problem (distinct from the VRAM/RAM-leak reports).
5. Cosmetic: restart ghostty on `desktop` to clear the stuck PSI counter.
