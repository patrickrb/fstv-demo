# fstv-bsides-demo

Transmit analog NTSC-M from an ADALM-PLUTO on Windows to a Sony Watchman FDL-22, tuned to **US UHF channel 14 (visual carrier 471.25 MHz)**.

## What works on this host

**Cyclic playback** of a pre-rendered IQ file. The Pluto loads the buffer into its on-board DDR and the TX DMA loops it with zero USB load. All of Phase 1 (colour bars) and Phase 2 (video) use this path.

**Streaming is broken** on this host (native Windows + WinUSB). The pipeline `hacktv → iio_writedev` cannot sustain 32 MB/s complex-int16 IQ without USB micro-gaps, and any gap breaks NTSC horizontal sync. `scripts\tx-live.cmd` is retained as a stub for a future WSL2 + usbipd-win setup.

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

## Troubleshooting

- **Static but AFC locks** — usually the sample rate. Verify both hacktv (`-s 7993007`) and the Pluto TX DMA (`cf-ad9361-dds-core-lpc voltage0 sampling_frequency`) agree at 7993007.
- **iio_writedev rejects buffer size** — Pluto's cyclic DMA cap varies by firmware. ≤24 MB is safe on this host; we've seen 64 MB accepted. Shrink the clip if a larger buffer fails.
- **No picture, no AFC lock at all** — antenna on wrong SMA jack (must be **TX1**, the one furthest from USB) or no antenna attached.
- **hacktv silently exits** — give it ≥5 s of wall clock before diagnosing. It takes several seconds to initialize when `-s 7993007` is used.

## Legal & safety

Unlicensed analog TV RF transmission is not FCC-compliant even at the Pluto's ~5 dBm. Keep sessions short, indoors, and do not connect external antennas. For a public venue, prefer a direct coax feed + 30 dB attenuator — no radiation.
