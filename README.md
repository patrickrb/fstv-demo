# fstv-bsides-demo

Transmit analog NTSC-M from an ADALM-PLUTO on Windows to a Sony Watchman FDL-22, tuned to **US UHF channel 14 (visual carrier 471.25 MHz)**.

## What works on this host

**Cyclic playback only.** Short pre-rendered IQ clips get uploaded once to the Pluto's on-board DDR, and the TX DMA loops them from local memory — zero USB traffic during playback, so NTSC sync is rock-solid. Loop length is capped by DDR:

- Stock Pluto firmware: **~24 MB ≈ 0.75 s**
- `tezuka_fw` (currently flashed — see "Firmware notes" below): **~60 MB ≈ 2 s**

**Real-time streaming is not possible** on stock Pluto Rev.C / AD9363A hardware. Both WinUSB (native Windows) and libiio `usb:` from WSL2 cap at ~25 MiB/s sustained — the Pluto's Zynq ARM iiod + AD9361 TX DMA + USB 2.0 ceiling. NTSC-M at 7.993 Msps complex-int16 needs **30.5 MiB/s** and underruns at anything less, producing no usable signal. Firmware work (tezuka, v0.39, libiio 0.26 host-side, mirrored WSL networking, usbipd-win passthrough, every buffer size) all confirmed this ceiling. `scripts\tx-live.cmd` remains as a cautionary stub.

For demos: either (a) loop a single short clip, or (b) rotate through several short clips with `scripts/tx-cycle.sh` — the Watchman re-locks in ~1 s at each clip boundary but holds cleanly between swaps.

## One-command demo (WSL)

From the repo root, after `scripts/install-linux.sh` + usbipd-win attach:

```bash
./demo.sh
```

Auto-renders `media/bars.iq16` on first run, then loops it. If you've rendered any clips into `media/channel/*.iq16`, it rotates through them 30 s each instead of just bars. Ctrl-C stops.

## Quick start

Install Phase 0 prerequisites (below), then:

```cmd
scripts\fetch-media.cmd                                        :: download demo trailer
scripts\tx-testpattern.cmd                                     :: Phase 1: colour bars (auto-renders IQ on first run)
scripts\render-iq.cmd media\bbb-trailer.mp4 10 2 media\bbb-clip.iq16   :: Phase 2: trim + render 2s clip
scripts\tx-file.cmd media\bbb-clip.iq16                        :: Phase 2: cyclic playback
```

Tune the Watchman to UHF channel 14 for all three.

## Phase 0 — one-time setup

- [x] PlutoSDR USB drivers — libiio tools (`iio_info`, `iio_writedev`) must be on PATH. Provided by the Analog Devices "PlutoSDR-M2k USB Drivers" installer.
- [x] FFmpeg — on PATH. Installed here via `winget install Gyan.FFmpeg`.
- [x] hacktv — installed via <https://github.com/steeviebops/hacktv-gui-installer/releases> (downloads fsphil's Windows build into `%APPDATA%\hacktv-gui\bin\`). Scripts auto-locate it.

PothosSDR / SoapySDR are **not** used on this host — the 2021.07 PothosSDR bundle omits SoapyPlutoSDR, and the scripts bypass SoapySDR entirely by streaming IQ through `iio_writedev`.

Verify:

```cmd
iio_info -u ip:192.168.2.1
ffmpeg -version
```

## Scripts

| Script | What it does |
|--------|-------------|
| `_find-hacktv.cmd` | Helper: sets `%HACKTV%` to the hacktv.exe full path. |
| `_config-pluto.cmd <lo> <rate> <bw> <gain>` | Helper: configures Pluto TX LO / rate / BW / hardwaregain via `iio_attr`. |
| `render-bars.cmd <out.iq16> [secs]` | Render colour-bars NTSC-M IQ at 7993007 sps. |
| `render-iq.cmd <video> <start_s> <dur_s> <out.iq16>` | Trim an MP4 with ffmpeg, render to NTSC-M IQ with hacktv. |
| `fetch-media.cmd` | Download the demo Big Buck Bunny trailer (CC-BY). |
| `tx-testpattern.cmd [gain_db]` | Phase 1: cyclic-play colour bars (auto-renders `media\bars.iq16` on first run). |
| `tx-file.cmd <iq16> [gain_db]` | Phase 2: cyclic-play any pre-rendered .iq16 file. |
| `tx-live.cmd` | Phase 3 stub (streaming; doesn't work on native Windows, see above). |

## Constants baked into the scripts

| Parameter | Value | Why |
|-----------|-------|-----|
| LO frequency | 471,250,000 Hz | NTSC-M visual carrier for US UHF ch 14 |
| Sample rate | 7,993,007 Hz | Only NTSC-compatible rate the Pluto DMA will accept. Using any other rate (e.g. 8 MHz) drifts NTSC frame timing vs. the DAC clock and the Watchman won't sync even in cyclic mode. |
| RF bandwidth | 8,000,000 Hz | Matches sample rate; comfortably contains the 6 MHz NTSC signal plus aural subcarrier. |
| Hardware gain | 0 dB (max) | Pluto `hardwaregain_available = [-89.75 0.25 0.0]`; 0 is the ceiling, ~+5 dBm at UHF. Lower is fine if the Watchman is inches away. |

## Channel reference

To change channel, edit `LO=` at the top of the tx scripts.

| Ch | Visual carrier (Hz) | Notes |
|----|---------------------|-------|
| 14 | 471250000 | Default |
| 21 | 513250000 | Fallback if ch 14 has interference |
| 36 | 603250000 | Mid-UHF fallback |

## Linux / WSL2 cyclic-playback path

Runs from WSL2 Ubuntu on the Windows host with the Pluto passed through via `usbipd-win` (so libiio uses the `usb:` URI directly, bypassing Windows RNDIS/TCP).

### One-time setup

```bash
# 1. Install toolchain
scripts/install-linux.sh

# 2. On the Windows side (PowerShell; admin for `bind` the first time), find the Pluto BUSID and pass it through:
#      usbipd list
#      usbipd bind --busid <id>
#      usbipd attach --wsl --busid <id> --auto-attach

# 3. Verify
iio_info -u usb: | head
```

### Play something

```bash
scripts/tx-testpattern.sh                                            # auto-renders media/bars.iq16 + cyclic loop
scripts/render-iq.sh <video> <start_s> <dur_s> <out.iq16>            # render a ≤2 s clip
scripts/tx-file.sh <out.iq16>                                        # cyclic playback of any .iq16
scripts/tx-cycle.sh media/channel 30                                 # rotate *.iq16 in a dir, 30 s each
```

Tune the Watchman to **UHF ch 14**. Ctrl-C stops anything.

### Linux scripts

| Script | What it does |
|--------|-------------|
| `scripts/install-linux.sh` | apt install ffmpeg + libiio-utils + mbuffer + build deps; clone/build hacktv from Codeberg; persist sysctl. Idempotent. |
| `scripts/_config-pluto.sh <lo> <rate> <bw> <gain>` | Four `iio_attr` calls — Linux port of `_config-pluto.cmd`, defaulting to `PLUTO_URI=usb:`. |
| `scripts/render-bars.sh [out.iq16] [dur_s]` | Render NTSC-M colour bars to an IQ file. Default 1.5 s. |
| `scripts/render-iq.sh <video> <start_s> <dur_s> <out.iq16>` | Trim an MP4 + render to NTSC-M IQ. Enforces the ≤2 s cyclic cap. |
| `scripts/tx-file.sh <iq16> [gain]` | Cyclic playback of any pre-rendered .iq16. Loops until Ctrl-C. |
| `scripts/tx-testpattern.sh [gain]` | Auto-render `media/bars.iq16` on first run, then cyclic play. |
| `scripts/tx-cycle.sh [dir] [hold_s] [gain]` | Rotate through `*.iq16` in a directory, each held for `hold_s` seconds. Watchman re-locks in ~1 s at each swap. |

### Firmware notes

This host has been flashed with F5OEO's `tezuka_fw`. Practical differences vs. stock v0.39:

- `hw_model` reports `Rev.C (Z7010-AD9361)` — chip unlocked from AD9363A restrictions (broader LO + sample rate ranges; not used by these scripts but convenient).
- Cyclic DDR buffer ceiling raised: **~60 MiB safe / 63 MiB absolute max** (≈ 0.75 s → 2 s loops vs. stock's ~24 MiB).
- iiod runs with 3 USB pipes + SCHED_FIFO prio 99 pinned to CPU 1. Confirmed empirically: no sustained-throughput improvement for cI16 over USB (~24 MiB/s, same as stock).
- No cI8 host→Pluto TX streaming path for generic `iio_writedev` — tezuka's 8-bit mode is for its on-device DATV toolchain only.

Rollback: copy `firmware/plutosdr-fw-v0.39.pluto.frm` to the Pluto's mass-storage drive on Windows after `usbipd detach`, rename to `pluto.frm`, eject. 3–4 min flash cycle.

## Troubleshooting

- **Static but AFC locks** — usually the sample rate. Verify both hacktv (`-s 7993007`) and the Pluto TX DMA (`cf-ad9361-dds-core-lpc voltage0 sampling_frequency`) agree at 7993007.
- **iio_writedev rejects buffer size** — Pluto's cyclic DMA cap varies by firmware. On stock v0.39: ≤24 MiB safe; on tezuka: 60 MiB safe, 63 MiB max. Beyond the max you'll see `Unable to allocate buffer: Cannot allocate memory (12)`. Shrink the clip.
- **No picture, no AFC lock at all** — antenna on wrong SMA jack (must be **TX1**, the one furthest from USB) or no antenna attached.
- **hacktv silently exits** — give it ≥5 s of wall clock before diagnosing. It takes several seconds to initialize when `-s 7993007` is used.

## Legal & safety

Unlicensed analog TV RF transmission is not FCC-compliant even at the Pluto's ~5 dBm. Keep sessions short, indoors, and do not connect external antennas. For a public venue, prefer a direct coax feed + 30 dB attenuator — no radiation.
