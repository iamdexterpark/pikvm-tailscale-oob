# Runbook 04 — Video Streamer Optimization

Tune the hardware encoder and frame-rate parameters to match target host video outputs, ensuring smooth WebRTC performance.

---

## 1. Goal & Prerequisites
- **Objective:** Match the KVM encoder frame pacing to target refresh rates, configure GOP keyframe overrides, and verify resource headroom.
- **Estimated Time:** 15 Minutes
- **Prerequisites:**
  - Runbooks 01, 02, and 03 completed.
  - Active video capture locked on a target host.
  - Read [TUNING.md](../../../../docs/TUNING.md) for the media engineering details.

---

## 2. Execution Steps

### Step 1: Measure Target Refresh Rate
1. Query the streamer status to detect the incoming refresh rate (`captured_fps`):
   ```bash
   BASE="https://localhost"
   AUTH=(-H "X-KVMD-User: admin" -H "X-KVMD-Passwd: admin")

   curl -sk "${AUTH[@]}" "$BASE/api/streamer" | jq '.result.streamer.source'
   ```
2. Note the value of `captured_fps`. This incoming rate dictates the encoder configuration.

### Step 2: Determine Frame Rate & GOP Target
Select settings based on the target refresh rate:

| Source `captured_fps` | Set `desired_fps` | Set `h264_gop` | Purpose |
|---|---|---|---|
| **60 Hz** | `30` | `30` | Halves signal cleanly (60/30 = 2) |
| **50 Hz** | `25` | `25` | Halves signal cleanly (50/25 = 2) |
| **30 Hz** | `15` or `30` | `15` or `30` | Matches divisor targets |

> [!IMPORTANT]
> If the source outputs 50Hz, do not set the KVM to 30 fps. Because 50 is not divisible by 30, the encoder will drop frames unevenly, causing video stuttering. Lock the KVM to 25 fps.

### Step 3: Write Overrides & Restart Service
1. Edit `/etc/kvmd/override.yaml`:
   ```bash
   rw
   $EDITOR /etc/kvmd/override.yaml
   ```
2. Configure settings (the example below uses a 50Hz source target):
   ```yaml
   kvmd:
       streamer:
           desired_fps: 25
           h264_gop: 25
           h264_bitrate: 6000
   ```
3. Restart `kvmd` and lock the rootfs:
   ```bash
   systemctl restart kvmd
   ro
   ```

---

## 3. SRE Verification Check

Validate frame pacing, capture loops, and CPU load under active video streaming.

### 1. Frame Pacing Validation Check
From a terminal, query the active frame rate output repeatedly:
```bash
for i in $(seq 1 5); do
  curl -sk "${AUTH[@]}" "$BASE/api/streamer" | jq '.result.streamer.h264.fps'
  sleep 2
done
```
*Expected Output (at 25 fps target):*
```
25
25
25
25
25
```
> [!IMPORTANT]
> The frame rate must remain steady. If the rate fluctuates wildly (e.g. `25`, `14`, `1`, `24`), verify that the CPU is not throttled or pegged at 100% capacity.

### 2. Host Headroom Check
Verify temperature and CPU load:
```bash
curl -sk "${AUTH[@]}" "$BASE/api/info?fields=hw" | jq '.result.hw.health'
```
*Expected Output:*
```json
{
  "cpu": {
    "percent": 14.5
  },
  "temp": {
    "cpu": 42.1
  },
  "throttling": {
    "raw_flags": "0x0"
  }
}
```

---

## 4. Rollback & Troubleshooting

### Saturated Encoder (High CPU Load / Frame Drops):
- If the CPU load exceeds 80% and the frame rate drops under motion:
  1. Mount the disk read-write: `rw`.
  2. Reduce `h264_bitrate` to `4000` or drop `desired_fps` to `15` (for 30/60Hz targets) / `10` (for 50Hz targets).
  3. Restart the service: `systemctl restart kvmd` and set to read-only: `ro`.

### Restoring Factory Defaults:
- Clear overrides to reset the streamer to stock parameters:
  ```bash
  rw
  sed -i '/streamer:/,$d' /etc/kvmd/override.yaml
  systemctl restart kvmd
  ro
  ```
