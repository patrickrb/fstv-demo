#!/usr/bin/env bash
# One-time toolchain install for the Linux/WSL2 streaming path.
#
# Installs: ffmpeg, libiio-utils, mbuffer, hacktv (from Codeberg).
# Applies:  setcap cap_sys_nice=eip on iio_writedev (so chrt -f 50 works without sudo),
#           persistent sysctl tuning for TCP socket buffers (iiod uses TCP).
#
# Idempotent: re-running is safe. Re-run after any 'apt upgrade' of libiio-utils
# so setcap is re-applied to the new binary.
#
# Usage: scripts/install-linux.sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
SRC_DIR="${HACKTV_SRC_DIR:-$HOME/src/hacktv}"

echo "=== [1/5] apt install ==="
sudo apt-get update
sudo apt-get install -y \
    build-essential git pkg-config curl jq \
    ffmpeg \
    libiio-utils libiio0 libiio-dev \
    libhackrf-dev \
    libavutil-dev libavdevice-dev libavformat-dev libavcodec-dev \
    libswresample-dev libswscale-dev \
    mbuffer util-linux libcap2-bin

echo "=== [2/5] clone + build hacktv ==="
if [[ ! -d "$SRC_DIR/.git" ]]; then
    mkdir -p "$(dirname "$SRC_DIR")"
    git clone https://codeberg.org/fsphil/hacktv.git "$SRC_DIR"
else
    echo "hacktv repo already present at $SRC_DIR (pulling latest)"
    git -C "$SRC_DIR" pull --ff-only || echo "(warn) git pull failed; keeping current checkout"
fi

pushd "$SRC_DIR/src" >/dev/null
make -j"$(nproc)"
sudo make install
popd >/dev/null

echo "=== [3/5] hacktv sanity check ==="
hacktv -h >/dev/null 2>&1 || hacktv --help >/dev/null 2>&1 || { echo "hacktv did not execute"; exit 1; }
echo "hacktv installed at: $(command -v hacktv)"

echo "=== [4/5] setcap on iio_writedev (re-apply each install) ==="
IIO_WRITEDEV=$(command -v iio_writedev)
sudo setcap 'cap_sys_nice=eip' "$IIO_WRITEDEV"
getcap "$IIO_WRITEDEV"

echo "=== [5/5] persist sysctl tuning ==="
SYSCTL_FILE=/etc/sysctl.d/99-pluto.conf
sudo tee "$SYSCTL_FILE" >/dev/null <<'EOF'
# fstv-demo: large TCP socket buffers so WSL -> iiod (Pluto) can ride 32 MB/s
# without backpressure stalls that break NTSC horizontal sync.
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.tcp_rmem = 4096 16777216 33554432
net.ipv4.tcp_wmem = 4096 16777216 33554432
EOF
sudo sysctl --system >/dev/null

echo
echo "Install complete."
echo "  ffmpeg:        $(command -v ffmpeg)"
echo "  hacktv:        $(command -v hacktv)"
echo "  iio_writedev:  $IIO_WRITEDEV  (cap_sys_nice=eip)"
echo "  mbuffer:       $(command -v mbuffer)"
echo "  sysctl:        $SYSCTL_FILE"
echo
echo "Verify Pluto reachable: iio_info -u ip:192.168.2.1 | head"
