#!/usr/bin/env bash
# One command to run the demo. From the repo root:
#
#   ./demo.sh
#
# What it does:
#   1. Verifies the Pluto is reachable (via usbipd-win -> WSL passthrough).
#   2. Auto-renders media/bars.iq16 on first run.
#   3. If media/channel/*.iq16 exists, rotates through those clips (30 s each).
#      Otherwise loops colour bars forever.
#   4. Tune your Sony Watchman to UHF channel 14 (visual carrier 471.25 MHz).
#
# Ctrl-C to stop.
#
# To add clips to the rotation:
#   mkdir -p media/channel
#   scripts/render-iq.sh <video.mp4> <start_s> <dur_s> media/channel/<name>.iq16
#   (re-run ./demo.sh to pick them up)

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

GAIN=${1:-0}

banner() {
    cat <<'EOF'
────────────────────────────────────────────────────────────────
  fstv-bsides-demo  ·  NTSC-M on US UHF ch 14 (471.25 MHz)
  Tune your Sony Watchman FDL-22 now.    Ctrl-C to stop.
────────────────────────────────────────────────────────────────
EOF
}

fail() {
    echo >&2
    echo "ERROR: $*" >&2
    exit 1
}

banner

# 1. Tool check
for t in hacktv iio_info iio_attr iio_writedev; do
    command -v "$t" >/dev/null || fail "Missing '$t'. Run: scripts/install-linux.sh"
done

# 2. Pluto reachable?
URI=${PLUTO_URI:-usb:}
if ! iio_info -u "$URI" >/dev/null 2>&1; then
    if iio_info -u ip:192.168.2.1 >/dev/null 2>&1; then
        echo "[pluto] usb: URI unavailable — falling back to ip:192.168.2.1"
        export PLUTO_URI=ip:192.168.2.1
        URI=$PLUTO_URI
    else
        fail "Pluto not reachable via 'usb:' or 'ip:192.168.2.1'.
       From a Windows PowerShell:
           usbipd attach --wsl --busid <id> --auto-attach
       (or plug in the Pluto if it's not connected)"
    fi
fi
echo "[pluto] reachable via $URI"

# 3. Bars: auto-render if missing
BARS=media/bars.iq16
if [[ ! -s "$BARS" ]]; then
    echo "[bars] first run — rendering media/bars.iq16 (~15s)"
    scripts/render-bars.sh "$BARS" >/dev/null
fi
echo "[bars] $BARS ready ($(du -h "$BARS" | cut -f1))"

# 4. Pick mode: single bars loop, or multi-clip channel rotation
shopt -s nullglob
CHANNEL_CLIPS=(media/channel/*.iq16)
if (( ${#CHANNEL_CLIPS[@]} > 0 )); then
    echo "[channel] ${#CHANNEL_CLIPS[@]} clip(s) in media/channel — rotating (30 s each)"
    echo
    exec scripts/tx-cycle.sh media/channel 30 "$GAIN"
else
    echo "[channel] no clips in media/channel — looping bars"
    echo "[tip]     add clips with: scripts/render-iq.sh <video> <start> <dur> media/channel/<name>.iq16"
    echo
    exec scripts/tx-file.sh "$BARS" "$GAIN"
fi
