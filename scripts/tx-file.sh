#!/usr/bin/env bash
# Cyclic playback of a pre-rendered IQ file on the Pluto. Linux port of
# tx-file.cmd, targeting WSL + usbipd-win passthrough (usb: URI).
#
# Usage: tx-file.sh <path-to-iq16> [gain_db]
# Produce the .iq16 file first with scripts/render-iq.sh or scripts/render-bars.sh.
#
# Runs until Ctrl-C. The Pluto DMA stores the full buffer in DDR and replays
# it — zero USB load during playback, so no jitter can break NTSC sync.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename "$0") <path-to-iq16> [gain_db]" >&2
    echo "Produce the .iq16 file with: scripts/render-iq.sh <video> <start_s> <dur_s> <out.iq16>" >&2
    exit 1
fi

INPUT=$1
GAIN=${2:-0}

[[ -f "$INPUT" ]] || { echo "Input IQ file not found: $INPUT" >&2; exit 1; }

LO=471250000
RATE=7993007
BW=8000000
URI=${PLUTO_URI:-usb:}

FILESIZE=$(stat -c %s "$INPUT")
SAMPLES=$((FILESIZE / 4))
MAX_SAMPLES=$((60 * 1024 * 1024 / 4))
if (( SAMPLES > MAX_SAMPLES )); then
    echo "ERROR: $INPUT is $(du -h "$INPUT" | cut -f1), which exceeds the cyclic DDR ceiling (~60 MiB = 1.97s)." >&2
    echo "       Re-render with a shorter duration." >&2
    exit 1
fi

"$SCRIPT_DIR/_config-pluto.sh" "$LO" "$RATE" "$BW" "$GAIN"

echo
echo "Cyclic playback: $INPUT"
printf "  URI=%s  LO=%d Hz  rate=%d sps  gain=%s dB  samples=%d  loop=%.2fs\n" \
       "$URI" "$LO" "$RATE" "$GAIN" "$SAMPLES" "$(awk -v s="$SAMPLES" -v r="$RATE" 'BEGIN{print s/r}')"
echo "  Tune Watchman to UHF ch 14. Press Ctrl-C to stop."
echo

exec iio_writedev -u "$URI" -c -b "$SAMPLES" cf-ad9361-dds-core-lpc voltage0 voltage1 < "$INPUT"
