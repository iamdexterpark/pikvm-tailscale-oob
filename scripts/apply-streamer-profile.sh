#!/usr/bin/env bash
# apply-streamer-profile.sh — apply a source-matched H.264 profile to a PiKVM streamer.
# Picks a clean FPS = integer divisor of the measured source refresh, GOP = FPS (1s keyframe).
#
# Usage:
#   BASE=https://oob-kvm.<tailnet>.ts.net KVMD_USER=admin KVMD_PASS=secret ./apply-streamer-profile.sh [bitrate]
#
# Optional: pass bitrate kbps as $1 (default 6000).
set -euo pipefail

BASE="${BASE:?set BASE}"; USER="${KVMD_USER:-admin}"; PASS="${KVMD_PASS:?set KVMD_PASS}"
BITRATE="${1:-6000}"
AUTH=(-H "X-KVMD-User: ${USER}" -H "X-KVMD-Passwd: ${PASS}")
CURL=(curl -sk --max-time 10 "${AUTH[@]}")

# 1. Measure source refresh
SRC=$("${CURL[@]}" "$BASE/api/streamer" | python3 -c 'import sys,json;print(int(round(json.load(sys.stdin)["result"]["streamer"]["source"]["captured_fps"])))')
echo "measured source captured_fps: $SRC"

# 2. Choose clean target FPS (largest sane integer divisor <= 30)
pick_fps() {
  local s=$1
  for f in 30 25 24 20 15; do
    if [ "$f" -le "$s" ] && [ $(( s % f )) -eq 0 ]; then echo "$f"; return; fi
  done
  # fallback: half the source if even, else source itself capped at 30
  if [ $(( s % 2 )) -eq 0 ]; then echo $(( s / 2 )); else echo $(( s>30?30:s )); fi
}
FPS=$(pick_fps "$SRC")
GOP=$FPS
echo "chosen desired_fps=$FPS  h264_gop=$GOP  h264_bitrate=$BITRATE"

# 3. Apply
"${CURL[@]}" -X POST -o /dev/null -w "set_params HTTP %{http_code}\n" \
  "$BASE/api/streamer/set_params?desired_fps=${FPS}&h264_gop=${GOP}&h264_bitrate=${BITRATE}"

# 4. Verify cadence
echo "verifying cadence (6x)..."
for i in $(seq 1 6); do
  "${CURL[@]}" "$BASE/api/streamer" | python3 -c 'import sys,json;s=json.load(sys.stdin)["result"]["streamer"];print("  emit:",s["h264"]["fps"],"src:",s["source"]["captured_fps"],"gop:",s["h264"]["gop"])'
  sleep 2
done
echo "Done. Persist via /etc/kvmd/override.yaml (remount rw) — see runbook 04."
