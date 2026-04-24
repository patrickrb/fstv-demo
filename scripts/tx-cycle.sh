#!/usr/bin/env bash
# Rotate through a directory of .iq16 clips. Each clip loops cyclically for
# HOLD seconds, then we tear down iio_writedev and start the next. The Watchman
# re-locks in ~1 s at each swap (brief roll/static), then holds cleanly until
# the next swap.
#
# Usage: tx-cycle.sh [dir=media/channel] [hold_s=30] [gain_db=0]
#
# Put any number of .iq16 files in the directory (produced by render-iq.sh or
# render-bars.sh). Exit with Ctrl-C; signal is trapped and passed to the child.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

DIR=${1:-$REPO_ROOT/media/channel}
HOLD=${2:-30}
GAIN=${3:-0}

[[ -d "$DIR" ]] || { echo "Directory not found: $DIR" >&2; echo "Create it and drop .iq16 files in, e.g. via scripts/render-iq.sh" >&2; exit 1; }

shopt -s nullglob
CLIPS=("$DIR"/*.iq16)
if (( ${#CLIPS[@]} == 0 )); then
    echo "No .iq16 files in $DIR" >&2
    exit 1
fi

echo "Cycling ${#CLIPS[@]} clip(s) from $DIR, ${HOLD}s each, forever. Ctrl-C to stop."
for c in "${CLIPS[@]}"; do
    echo "  - $(basename "$c") ($(du -h "$c" | cut -f1))"
done
echo

CHILD_PID=""
cleanup() {
    trap - INT TERM
    if [[ -n "$CHILD_PID" ]]; then kill "$CHILD_PID" 2>/dev/null || true; wait "$CHILD_PID" 2>/dev/null || true; fi
    exit 0
}
trap cleanup INT TERM

while true; do
    for clip in "${CLIPS[@]}"; do
        echo "[$(date +%H:%M:%S)] playing $(basename "$clip") for ${HOLD}s"
        "$SCRIPT_DIR/tx-file.sh" "$clip" "$GAIN" &
        CHILD_PID=$!
        sleep "$HOLD" || true
        kill "$CHILD_PID" 2>/dev/null || true
        wait "$CHILD_PID" 2>/dev/null || true
        CHILD_PID=""
        # Give the USB interface a moment to release before next claim.
        sleep 2
    done
done
