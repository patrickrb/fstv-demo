#!/usr/bin/env bash
# Render NTSC-M colour bars as a cyclic IQ buffer for the Pluto. Linux port
# of render-bars.cmd.
#
# Usage: render-bars.sh [out.iq16] [duration_s]
# Defaults: media/bars.iq16, 1.5 s (fits ~45 MiB, well under tezuka 63 MiB cap)

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

OUT=${1:-$REPO_ROOT/media/bars.iq16}
DUR=${2:-1.5}

RATE=7993007
EXPECTED_SAMPLES=$(awk -v r="$RATE" -v d="$DUR" 'BEGIN{printf "%d", r*d}')
TARGET_BYTES=$((EXPECTED_SAMPLES * 4))

command -v hacktv >/dev/null || { echo "Missing hacktv; run scripts/install-linux.sh"; exit 1; }
mkdir -p "$(dirname "$OUT")"

echo "Rendering ${DUR}s of NTSC-M colour bars @ ${RATE} sps -> $OUT"
rm -f "$OUT"

# hacktv's colourbars is infinite; let it run long enough to exceed target, then SIGTERM.
# Wall-clock budget: DUR seconds of IQ, but hacktv can encode faster than realtime
# on this 8-core host (~1.2x faster), plus ~4s init. Give ~DUR+8s.
WALL=$(awk -v d="$DUR" 'BEGIN{printf "%d", d+8}')
timeout --signal=TERM "${WALL}" hacktv -o "file:$OUT" -t int16 -m m -s "$RATE" test:colourbars 2>&1 | grep -vE '^$|^Warning|^Next|^Video|^Sample|^audio|^Opening|^Input|^  |^Stream|^Using|^No audio|^Duration|Caught signal' || true

ACTUAL=$(stat -c %s "$OUT" 2>/dev/null || echo 0)
if (( ACTUAL < TARGET_BYTES )); then
    echo "ERROR: hacktv produced $ACTUAL bytes, wanted $TARGET_BYTES. Increase WALL budget." >&2
    exit 1
fi
truncate -s "$TARGET_BYTES" "$OUT"
echo "    wrote $(du -h "$OUT" | cut -f1) = ${EXPECTED_SAMPLES} samples = ${DUR}s loop"
