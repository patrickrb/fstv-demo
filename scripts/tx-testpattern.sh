#!/usr/bin/env bash
# Cyclic playback of NTSC-M colour bars. Auto-renders media/bars.iq16 on first run.
# Linux port of tx-testpattern.cmd.
#
# Usage: tx-testpattern.sh [gain_db]

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

GAIN=${1:-0}
BARS=$REPO_ROOT/media/bars.iq16

if [[ ! -s "$BARS" ]]; then
    echo "No bars.iq16 yet — rendering..."
    "$SCRIPT_DIR/render-bars.sh" "$BARS"
fi

exec "$SCRIPT_DIR/tx-file.sh" "$BARS" "$GAIN"
