#!/usr/bin/env bash
# path-probe.sh — quantify the mesh path to the PiKVM: loss, jitter, direct-vs-relayed.
# Usage: ./path-probe.sh <tailnet-host-or-ip> [count]
set -euo pipefail
HOST="${1:?usage: path-probe.sh <host-or-ip> [count]}"
COUNT="${2:-150}"

echo "== ICMP $COUNT pkts @100ms to $HOST =="
ping -c "$COUNT" -i 0.1 "$HOST" | tail -3

if command -v tailscale >/dev/null 2>&1; then
  echo "== tailscale ping (direct vs DERP) x4 =="
  for i in 1 2 3 4; do tailscale ping "$HOST" 2>&1 | tail -1; done
  echo "== netcheck =="
  tailscale netcheck 2>&1 | sed -n '1,12p'
fi
