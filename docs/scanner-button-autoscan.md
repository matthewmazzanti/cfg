# Button-triggered auto-scan for the ScanSnap iX1300 — 2026-07-14

## Goal

On the `print` host, press the scanner's **Scan** button and have the whole
loaded stack scanned (duplex), bundled into a single PDF, and dropped into a
permanent local folder — reproducing the native ScanSnap Home one-touch flow,
declaratively and offline. No cloud, no vendor daemon.

Target output: `/home/mmazzanti/scans/scan-YYYYMMDD-HHMMSS.pdf`
(`/home` is a persistent ZFS dataset, so it survives the root rollback).

## Hardware / device facts (verified on the box)

- **Fujitsu ScanSnap iX1300**, USB `04c5:162c`, connected to `print`.
  - `iSerial` index 0 → **no serial string reported** (unlike the Brother printer,
    which reports `U63878K2N151402`). Identify by VID:PID.
  - USB interface: **vendor-specific class (255)**, `bNumEndpoints 2`:
    `0x81 IN` **Bulk** (data), `0x02 OUT` **Bulk** (commands). **No interrupt
    endpoint.** Kernel binds no HID/input driver (`/dev/input` empty, dmesg clean).
- **SANE**: driven by the stock `fujitsu` backend, no firmware needed.
  - `scanimage -L` → `fujitsu:ScanSnap iX1300:21514` (trailing index may vary).
  - Sources: `ADF Front | ADF Back | ADF Duplex | Card Front | Card Back |
    Card Duplex` (default `ADF Front`). **ADF-only, no flatbed.**
  - Sensors exposed (all `[hardware]`, read-only): **`--scan` (the Scan button)**,
    `--email`, `--page-loaded`, `--card-loaded`, `--top-edge`, `--a3/a4/b4/b5-paper`,
    `--power-save`, `--function`.
  - `sane_start` on an **empty ADF blocks ~7.8 s (fixed)** then returns
    `NO_DOCS` (exit 7). A 25 s ceiling still returned at 7.796 s → the wait
    window is hardwired; **no option to extend it** (only `--sleeptimer` for power).

## Mechanism analysis — why polling, definitively

The button is **not an event** anywhere in the stack:

- **SANE layer:** pure pull API. `--scan` is a read-on-demand sensor; there is no
  callback, no fd to `select()` on, no blocking "wait for button" primitive.
- **USB layer:** no interrupt endpoint (confirmed in descriptors). The only way to
  learn button state is to *ask* — a vendor status query over the bulk command pipe.
- **Protocol:** the query is **`GET_HW_STATUS`, SCSI opcode `0xC2`**, returning a
  ~12-byte status word carrying the button + paper-presence bits. This is exactly
  what the `fujitsu` backend runs to populate `--scan`.

Independent reverse engineering confirms there is no hidden event path: the
`s1500d` author went all the way down to raw libusb on this ScanSnap family and
**still polls** `GET_HW_STATUS`. So polling isn't a SANE compromise — it *is* the
device's contract, and almost certainly what ScanSnap Home does too. Every known
implementation (scanbd, insaned, s1500d) polls.

## Prior art

- **scanbd** — the standard SANE button daemon. Polls SANE sensors every 500 ms
  (~25 SCSI commands/cycle for fujitsu). Locks the device; needs the `scanbm`
  proxy to release it for the actual scan. **No NixOS module** → hand-rolled
  systemd + a large `scanbd.conf` either way.
- **insaned** (github.com/abusenius/insaned) — "simple daemon for polling button
  presses on SANE scanners." Lighter than scanbd, still SANE-poll.
- **s1500d** (github.com/mmacpherson/s1500d) — **the closest match to our goal.**
  - **Rust** (~90%), Apache-2.0/MIT.
  - Poller: **raw libusb**, sends `GET_HW_STATUS` every **100 ms**, decodes button
    + paper bits. One command/cycle vs scanbd's ~25.
  - Scan: daemon **releases the USB device**, then runs a **handler script**; the
    bundled handler is **`scanimage` + `img2pdf`** → PDF.
  - Protocol reverse-engineered from USB captures + the SANE fujitsu backend source.
    **S1500-specific**: command/response byte layout and bit positions are
    hardcoded to that model. VID/PID configurable via udev.
  - Its architecture (release device → `scanimage` → `img2pdf`) is exactly the
    shape we want; only its *poller* differs from the SANE-sensor route.

## Decision — preferred direction

**Follow and extend the s1500d approach** (raw-USB `GET_HW_STATUS` poll +
release-to-`scanimage` handler), via one of:

1. **Upstream contribution to s1500d** — add ScanSnap **iX1300** support: verify
   and adapt the `0xC2` command + response decode for our model (USB captures on
   the box and/or the fujitsu backend source), contribute back. Rust; would need a
   `buildRustPackage` derivation in the flake.
2. **Emulate a simpler model in Python** — a small daemon (pyusb) that polls
   `GET_HW_STATUS` over raw libusb, releases the interface, and shells out to
   `scanimage --source 'ADF Duplex' --batch` → `img2pdf`. No Rust toolchain; fits
   the repo's Python/shell `bin/` style.

Shared handler pattern (both options):

```
poll GET_HW_STATUS (~100 ms)
  └─ on Scan-button edge:
       release device
       scanimage --source 'ADF Duplex' --resolution 300 --mode Color \
                 --batch=/tmp/scan-%04d.png
       img2pdf /tmp/scan-*.png -o /home/mmazzanti/scans/scan-<ts>.pdf
       reclaim device, resume polling
```

### Alternative considered (fallback, not preferred)

**python-sane poll of the `--scan` SANE sensor** — same release→`scanimage`→
`img2pdf` handler, but the poller reads the already-working SANE sensor instead of
raw USB. Zero protocol reverse-engineering, rides the validated `fujitsu` backend,
~40 lines. Downsides vs the chosen direction: loads the full SANE stack to poll
(~25 cmds/cycle) and gives up the tight, self-contained raw-USB model. **Kept as
the low-risk fallback** if the iX1300 raw protocol proves finicky to pin down.

## Open questions / risks

- **iX1300 protocol may differ from the S1500** — the `0xC2` response layout / bit
  positions are the main unknown for the raw path. Needs verification via `usbmon`/
  Wireshark capture while pressing the button, or by reading the fujitsu backend's
  iX1300 handling. This is the gating task for options 1 and 2.
- **Device-lock handoff** — the fujitsu backend allows only one open handle
  (`DEVICE_BUSY` on a second). Any hold-open poller must release before `scanimage`
  and reclaim after. Inherent; small in code.
- **Duplex blank backs** — single-sided docs scanned duplex leave blank reverse
  pages. Decide: auto-drop blanks (backend/size threshold) vs keep all sides.
- **Power-save interaction** — confirm continuous polling doesn't prevent the
  scanner's `--sleeptimer` sleep, and that a button press wakes it and reads through.
- **Poll interval** — s1500d uses 100 ms; a SANE-sensor poll would start ~300 ms.
  Tune to taste (miss a fast tap → tighten).

## Next steps

1. Capture iX1300 USB traffic (`usbmon`) pressing Scan + loading paper; confirm the
   `GET_HW_STATUS` request/response and which bits mean button / page-loaded.
2. Prototype the poller (Rust fork or Python), print detected transitions only.
3. Wire the handler (`scanimage` batch → `img2pdf` → dated PDF in the output dir).
4. Package as a systemd service on `print` (+ udev rule for device access, output
   dir creation). Decide Rust `buildRustPackage` vs Python before this step.

## Current config state (as of this doc)

`sys/print/default.nix`: Brother HL-L2300D printing is finalized (declarative
`ensurePrinters`, CUPS + Avahi shared). Scanning is **CLI-only** for now —
`hardware.sane.enable = true`, `mmazzanti` in `scanner`. The scanservjs web UI was
added then **removed** (it fought impermanence: its tmpfiles-managed
`data/preview/default.jpg` store symlink broke under a `/persist` bind-mount).
This button-autoscan work is the next scanning increment.

## References

- s1500d: https://mmacpherson.github.io/s1500d/ · https://github.com/mmacpherson/s1500d
- insaned: https://github.com/abusenius/insaned
- scanbd (ArchWiki): https://wiki.archlinux.org/title/Scanner_Button_Daemon
- SANE fujitsu backend: https://man.archlinux.org/man/sane-fujitsu.5.en
