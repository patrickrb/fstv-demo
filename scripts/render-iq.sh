#!/usr/bin/env bash
# Trim + render an MP4 to an NTSC-M complex int16 IQ file for cyclic playback
# on the Pluto. Linux port of render-iq.cmd.
#
# Usage: render-iq.sh <input> <start_s> <dur_s> <out.iq16>
# Example: render-iq.sh media/bbb-trailer.mp4 10 1.5 media/bbb-clip.iq16
#
# Safe durations (tezuka/stock Pluto Rev.C):
#   ≤ 1.97 s  (60 MiB buffer, default safe)
#   ≤ 2.06 s  (63 MiB max observed on tezuka; stock typically caps ≤ 24 MiB = 0.75s)

set -euo pipefail

if [[ $# -lt 4 ]]; then
    echo "Usage: $(basename "$0") <input> <start_s> <dur_s> <out.iq16>" >&2
    echo "Example: $(basename "$0") media/bbb-trailer.mp4 10 1.5 media/bbb-clip.iq16" >&2
    exit 1
fi

INPUT=$1
START=$2
DUR=$3
OUT=$4

RATE=7993007
# Max safe buffer in bytes (tezuka cyclic DDR ceiling = 63 MiB, pick 60 for margin)
MAX_IQ_BYTES=$((60 * 1024 * 1024))
# Max samples = MAX_IQ_BYTES / 4
MAX_SAMPLES=$((MAX_IQ_BYTES / 4))
# Expected samples for this duration
EXPECTED_SAMPLES=$(awk -v r="$RATE" -v d="$DUR" 'BEGIN{printf "%d", r*d}')

if (( EXPECTED_SAMPLES > MAX_SAMPLES )); then
    MAX_DUR=$(awk -v m="$MAX_SAMPLES" -v r="$RATE" 'BEGIN{printf "%.2f", m/r}')
    echo "ERROR: duration ${DUR}s exceeds cyclic DDR ceiling (~${MAX_DUR}s)." >&2
    echo "       Shorten the clip or raise MAX_IQ_BYTES if your firmware allows." >&2
    exit 1
fi

for tool in ffmpeg hacktv; do
    command -v "$tool" >/dev/null || { echo "Missing $tool; run scripts/install-linux.sh"; exit 1; }
done

TRIMMED=$(mktemp --suffix=.mp4 /tmp/_hacktv_trim_XXXX)
trap 'rm -f "$TRIMMED"' EXIT

mkdir -p "$(dirname "$OUT")"

echo "[1/2] Trimming $INPUT  [${START}s +${DUR}s] -> $TRIMMED"
ffmpeg -hide_banner -loglevel warning -y -ss "$START" -t "$DUR" -i "$INPUT" -c copy "$TRIMMED"

echo "[2/2] Rendering NTSC-M IQ @ ${RATE} sps -> $OUT"
rm -f "$OUT"
# Let hacktv output more than DUR (it pre-rolls), then truncate to exact sample count.
timeout $((${DUR%.*} + 30)) hacktv -o "file:$OUT" -t int16 -m m -s "$RATE" "$TRIMMED" || true

ACTUAL=$(stat -c %s "$OUT" 2>/dev/null || echo 0)
TARGET_BYTES=$((EXPECTED_SAMPLES * 4))
if (( ACTUAL < TARGET_BYTES )); then
    echo "WARN: hacktv produced only $ACTUAL bytes (wanted ${TARGET_BYTES}). Clip may loop short; re-run with longer --dur or give hacktv more wall-clock time." >&2
    exit 0
fi
# Truncate DOWN to exactly TARGET_BYTES (round sample count)
truncate -s "$TARGET_BYTES" "$OUT"
echo "    wrote $(du -h "$OUT" | cut -f1) = ${EXPECTED_SAMPLES} samples = ${DUR}s loop"
