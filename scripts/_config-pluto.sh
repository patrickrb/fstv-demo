#!/usr/bin/env bash
# Configure Pluto TX path via iio_attr. Sets LO, sample rate, RF bandwidth, and gain.
# Usage: _config-pluto.sh <lo_hz> <rate_sps> <bw_hz> <gain_db>
# gain_db is hardware gain in dB (negative is attenuation; 0 is max, -89.75 is lowest).

set -euo pipefail

LO=${1:-}
RATE=${2:-}
BW=${3:-}
GAIN=${4:-}
URI=${PLUTO_URI:-usb:}

if [[ -z "$LO" || -z "$RATE" || -z "$BW" || -z "$GAIN" ]]; then
    echo "Usage: $(basename "$0") <lo_hz> <rate_sps> <bw_hz> <gain_db>" >&2
    exit 1
fi

echo "[pluto] URI=$URI  LO=$LO Hz  rate=$RATE sps  bw=$BW Hz  gain=$GAIN dB"
iio_attr -q -u "$URI" -c -o ad9361-phy altvoltage1 frequency "$LO"
iio_attr -q -u "$URI" -c -o ad9361-phy voltage0 sampling_frequency "$RATE"
iio_attr -q -u "$URI" -c -o ad9361-phy voltage0 rf_bandwidth "$BW"
iio_attr -q -u "$URI" -c -o ad9361-phy voltage0 hardwaregain "$GAIN"
