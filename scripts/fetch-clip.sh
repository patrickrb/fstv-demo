#!/usr/bin/env bash
# Download -> trim -> overlay callsign -> render NTSC-M IQ. End-to-end helper
# for populating media/channel/ with short clips for tx-cycle.sh / demo.sh.
#
# Usage:
#   fetch-clip.sh <slug> <url-or-ytsearch> <start_s> <dur_s>
#
# Examples:
#   fetch-clip.sh hack-the-planet 'ytsearch1:hackers 1995 hack the planet' 8 1.8
#   fetch-clip.sh wheres-the-beef https://archive.org/download/<id>/<file>.mp4 0 1.8
#
# Output: media/channel/<slug>.iq16 (≤60 MiB, ~≤1.97 s — enforced by render-iq.sh).
# Overlays the "K1AF" callsign in yellow-on-black at top-left of the video.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$REPO_ROOT"

if [[ $# -lt 4 ]]; then
    echo "Usage: $(basename "$0") <slug> <url-or-ytsearch:query> <start_s> <dur_s>" >&2
    exit 1
fi

SLUG=$1
URL=$2
START=$3
DUR=$4

CALLSIGN=${CALLSIGN:-K1AF}
FONT=${FONT:-/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf}
CHANNEL=media/channel
CACHE=media/source
mkdir -p "$CHANNEL" "$CACHE"

# yt-dlp must be on PATH
export PATH=$HOME/.local/bin:$PATH
command -v yt-dlp >/dev/null || { echo "yt-dlp not installed. curl ~/.local/bin/yt-dlp from github." >&2; exit 1; }
command -v ffmpeg  >/dev/null || { echo "ffmpeg missing. run scripts/install-linux.sh"; exit 1; }
[[ -f "$FONT" ]] || { echo "Font not found: $FONT. set FONT=<ttf>" >&2; exit 1; }

SRC="$CACHE/$SLUG.src.mp4"
OVER="$CACHE/$SLUG.over.mp4"
OUT="$CHANNEL/$SLUG.iq16"

# 1. Download (unless cached). Limit to ~720p to save space; any codec ffmpeg can re-encode.
if [[ ! -s "$SRC" ]]; then
    echo "[1/3] downloading $URL -> $SRC"
    yt-dlp --no-playlist --no-warnings -f "best[height<=720]/best" --merge-output-format mp4 -o "$SRC" "$URL"
else
    echo "[1/3] cached $SRC ($(du -h "$SRC" | cut -f1))"
fi

# 2. Trim + overlay callsign, normalize to 720x480 29.97 4:3 yuv420p.
# Drawtext places the callsign in top-left with a semi-opaque black box for legibility.
echo "[2/3] trimming/overlaying [$START + ${DUR}s] -> $OVER"
ffmpeg -hide_banner -loglevel warning -y \
    -ss "$START" -t "$DUR" -i "$SRC" \
    -vf "scale=720:480:flags=lanczos,setsar=1,fps=30000/1001,drawtext=fontfile=${FONT}:text='${CALLSIGN}':fontcolor=yellow:fontsize=36:x=24:y=24:box=1:boxcolor=black@0.55:boxborderw=8" \
    -pix_fmt yuv420p \
    -c:v libx264 -preset fast -crf 20 \
    -c:a aac -b:a 128k -ac 2 -ar 48000 \
    "$OVER"

# 3. Render to NTSC-M IQ
echo "[3/3] rendering IQ -> $OUT"
scripts/render-iq.sh "$OVER" 0 "$DUR" "$OUT"

echo "[done] $OUT ready"
