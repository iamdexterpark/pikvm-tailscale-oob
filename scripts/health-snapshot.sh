#!/usr/bin/env bash
# health-snapshot.sh — one-shot PiKVM health + stream + path snapshot via the kvmd HTTP API.
# Usage: BASE=https://oob-kvm.<tailnet>.ts.net KVMD_USER=admin KVMD_PASS=secret ./health-snapshot.sh
set -euo pipefail

BASE="${BASE:?set BASE, e.g. https://oob-kvm.tailnet.ts.net}"
USER="${KVMD_USER:-admin}"
PASS="${KVMD_PASS:?set KVMD_PASS}"
AUTH=(-H "X-KVMD-User: ${USER}" -H "X-KVMD-Passwd: ${PASS}")
CURL=(curl -sk --max-time 10 "${AUTH[@]}")

echo "== auth =="
"${CURL[@]}" -o /dev/null -w "auth_check HTTP %{http_code}\n" "$BASE/api/auth/check"

echo "== platform / health =="
"${CURL[@]}" "$BASE/api/info?fields=hw,fan,system" | python3 -c '
import sys,json
r=json.load(sys.stdin)["result"]
hw=r["hw"]; h=hw["health"]
print("  model     :", hw["platform"]["base"], "| kvmd", r["system"]["kvmd"]["version"])
print("  cpu%%      :", h["cpu"]["percent"], "| temp:", round(h["temp"]["cpu"],1), "C")
t=h["throttling"]; print("  throttle  : raw", hex(t["raw_flags"]),
      "| undervolt_now", t["parsed_flags"]["undervoltage"]["now"],
      "past", t["parsed_flags"]["undervoltage"]["past"])
f=r.get("fan",{}).get("state",{}).get("fan",{}); print("  fan pwm   :", f.get("pwm"))
'

echo "== streamer =="
"${CURL[@]}" "$BASE/api/streamer" | python3 -c '
import sys,json
r=json.load(sys.stdin)["result"]
print("  applied   :", r["applied"])
s=r["streamer"]; print("  h264      :", s["h264"]); print("  source    :", s["source"])
'

echo "== cadence (8x over ~16s) =="
for i in $(seq 1 8); do
  "${CURL[@]}" "$BASE/api/streamer" | python3 -c 'import sys,json;s=json.load(sys.stdin)["result"]["streamer"];print("  emit:",s["h264"]["fps"],"src:",s["source"]["captured_fps"])'
  sleep 2
done

echo "== recent log (errors/watchdog) =="
"${CURL[@]}" "$BASE/api/log?seek=120&follow=0" | grep -iE "Traceback|Error|watchdog" | tail -10 || echo "  (none)"

echo "== mesh path =="
if command -v tailscale >/dev/null 2>&1; then
  host="${BASE#https://}"; host="${host%%/*}"; host="${host%%.*}"
  tailscale ping "$host" 2>&1 | tail -1 || true
else
  echo "  (tailscale CLI not on this host)"
fi
