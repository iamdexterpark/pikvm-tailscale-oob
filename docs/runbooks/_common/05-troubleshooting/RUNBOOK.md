# Runbook 05 — Troubleshooting Playbook

Operational runbook to triage, isolate, and resolve platform anomalies in the out-of-band management plane.

---

## 1. Fast Triage Snapshot

Run this triage suite to diagnose the host, path quality, and active streamer status:

```bash
# Define target host credentials
BASE="https://oob-kvm"
AUTH=(-H "X-KVMD-User: admin" -H "X-KVMD-Passwd: password")

# 1. Test credentials authentication status
curl -sk "${AUTH[@]}" "$BASE/api/auth/check" -o /dev/null -w "Auth HTTP Status: %{http_code}\n"

# 2. Query hardware health and thermal states
curl -sk "${AUTH[@]}" "$BASE/api/info?fields=hw,fan,system" | jq '.result' | head -n 25

# 3. Query the video capture and active encoder parameters
curl -sk "${AUTH[@]}" "$BASE/api/streamer" | jq '.result.streamer | {source, h264}'

# 4. Check Tailscale mesh path routing
tailscale ping oob-kvm
```

---

## 2. Symptom Isolation & Resolution Playbook

Follow this guide to isolate issues in specific layers:

### Symptom: Session freezes, then takes ≥1.0 seconds to recover
* **Isolate:** Check the GOP parameter value.
  ```bash
  curl -sk "${AUTH[@]}" "$BASE/api/streamer" | jq '.result.streamer.h264.gop'
  ```
* **Reason:** If `gop` reads `0`, the encoder is not emitting regular keyframes. In lossy network environments, the browser decoder freezes until the next keyframe arrives.
* **Fix:** Update `/etc/kvmd/override.yaml` and set `h264_gop` to match the target frame rate. Follow [Runbook 04](../../profile-pikvm-v3-pi4/04-streamer-tuning/RUNBOOK.md).

### Symptom: Video stutters under motion, but network latency is low
* **Isolate:** Compare the target host's output refresh rate with the KVM streamer target:
  ```bash
  curl -sk "${AUTH[@]}" "$BASE/api/streamer" | jq '.result.streamer | {source_fps: .source.captured_fps, target_fps: .h264.fps}'
  ```
* **Reason:** If the source frame rate is not an integer multiple of the target (e.g., 50Hz source and 30 fps target), the encoder drops frames irregularly, creating visual judder.
* **Fix:** Change `desired_fps` in `/etc/kvmd/override.yaml` to a clean divisor (e.g., `25` for a 50Hz target).

### Symptom: Intermittent screen drops (source_fps reads 0)
* **Isolate:** Parse the system journal for service loop events:
  ```bash
  curl -sk "${AUTH[@]}" "$BASE/api/log?seek=120&follow=0" | grep -iE "watchdog|error|traceback" | tail -n 10
  ```
* **Reason 1 (Watchdog Loop):** If logs show `FileNotFoundError: /sys/class/rtc/rtc0/since_epoch`, the watchdog service is fail-looping on a Pi that lacks a physical RTC battery, causing CPU spikes.
  * *Fix:* Mount read-write and disable the watchdog:
    ```bash
    rw; systemctl disable --now kvmd-watchdog; ro
    ```
* **Reason 2 (HPD Quirks):** The target system's GPU is resetting its display target because the switch is polling HPD lines on inactive ports.
  * *Fix:* Verify that `ignore_hpd_on_top: true` is configured in `/etc/kvmd/override.yaml` under the `switch` block.

### Symptom: System changes revert after a host reboot
* **Reason:** The root filesystem is mounted read-only (`ro`) by default. Service adjustments or file changes will fail to persist unless you run the `rw` helper first.
* **Fix:** Apply changes using the remount pattern:
  ```bash
  rw
  systemctl disable --now <service_name>
  ro
  ```

### Symptom: SSH connections fail or hang
* **Reason 1 (Tailscale SSH):** The connection hangs on a re-authentication prompt. This indicates Tailscale SSH is in `check` mode, which blocks automated scripts.
  * *Fix:* Update the Tailnet ACL to use `action: "accept"` instead of `action: "check"` for SSH access.
* **Reason 2 (User Error):** The connection is targeting the web console account (`admin`). The actual OS account on PiKVM is `root`.
  * *Fix:* Use the correct user credential when connecting:
    ```bash
    ssh root@oob-kvm
    ```

---

## 3. Escalation Diagnostics

If issues persist, gather a complete system telemetry report:
1. Run the health snapshot script:
   ```bash
   ./scripts/health-snapshot.sh
   ```
2. The script compiles temperature logs, throttling flags, encoder states, and mesh connection metrics into a single report to help diagnose issues.
