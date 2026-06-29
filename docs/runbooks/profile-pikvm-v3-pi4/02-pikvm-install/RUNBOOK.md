# Runbook 02 — PiKVM Installation & Physical Capture Configuration

Configure the physical capture card interface, KVM multiplexer switch, and keyboard/mouse emulation signals.

---

## 1. Goal & Prerequisites
- **Objective:** Cable signal paths, upload custom UART control firmware to the KVM switch, configure the multiplexer HPD ignore quirk, and verify video capture and HID keyboard/mouse injection APIs.
- **Estimated Time:** 25 Minutes
- **Prerequisites:**
  - Runbook 01 completed.
  - PiKVM v3 HAT seated on the Pi.
  - PiKVM-compatible 4-port HDMI/USB KVM Switch (EZCOO model).
  - HDMI and USB OTG data cables.
  - CH340 USB-to-UART TTL serial programming adapter (for switch firmware flash).
- **Reference Documentation:**
  - [Official PiKVM KVM Switch Documentation](https://docs.pikvm.org/switch/)
  - [Official EZCOO Switch Firmware Updating Guide](https://docs.pikvm.org/switch/#firmware-updating)
  - [KVM Switch Datasheet PDF](https://docs.pikvm.org/switch/switch_datasheet.pdf)
  - [PiKVM Multiport Extender Hardware Product](https://shop.hipi.io/product/pikvm-switch-multiport-extender)

---

## 2. Execution Steps

### Step 1: Flash KVM Switch Firmware
To allow the PiKVM to control port-switching via USB serial, you must flash custom firmware to the EZCOO switch.
1. Connect your CH340 USB-to-TTL serial adapter to the switch's internal programming header pins:
   ```
   CH340 TX  ────────► Switch RX
   CH340 RX  ────────► Switch TX
   CH340 GND ────────► Switch GND
   ```
2. Follow the [EZCOO Switch Firmware Updating Guide](https://docs.pikvm.org/switch/#firmware-updating) to download the ISP programming tool and load the custom firmware binary (`.hex` file).
3. Connect the switch to your workstation, launch the ISP tool, select the correct CH340 COM/tty port, and write the custom firmware to the flash memory. Confirm success before assembling.

### Step 2: Cable the Signal Paths
Assemble and wire the hardware components (utilizing the [PiKVM Switch Multiport Extender](https://shop.hipi.io/product/pikvm-switch-multiport-extender) if managing 4+ target hosts):

```
Target Host (e.g. Host A) HDMI Out ──────► switch port 1 (HDMI input)
Target Host (e.g. Host A) USB Port ──────◄ switch port 1 (USB/HID input)

HDMI/USB Switch Common HDMI Out ─────────► PiKVM CSI Bridge Input (HAT port)
HDMI/USB Switch Common USB Port ─────────◄ PiKVM USB OTG Data Port (Type-C data)
HDMI/USB Switch RS232/UART Control ──────◄ Pi USB Port (using CH340 Serial cable)
```

> [!WARNING]
> Use the dedicated USB-C **data** port on the Pi 4 (located on the same side as the power input) for target host HID injection. Connecting the target to a standard USB-A port on the Pi will not allow keyboard/mouse emulation to function.

### Step 3: Apply Switch Hotplug Quirks
To prevent signal renegotiation issues when switching target hosts:
1. SSH into the PiKVM as root.
2. Edit `/etc/kvmd/override.yaml`:
   ```bash
   rw
   $EDITOR /etc/kvmd/override.yaml
   ```
3. Append the switch configuration:
   ```yaml
   kvmd:
       switch:
           device: /dev/kvmd-switch        # Maps to the CH340 USB-to-serial device
           ignore_hpd_on_top: true         # Quirk: ignore hot-plug-detect pulses
   ```
4. Restart the daemon and lock the rootfs:
   ```bash
   systemctl restart kvmd
   ro
   ```

---

## 3. SRE Verification Check

Validate raw capture and HID injection status over the HTTP API.

### 1. HDMI Capture Status Check
Query the ustreamer source API status:
```bash
# Set credentials for authentication checks
BASE="https://localhost"
AUTH=(-H "X-KVMD-User: admin" -H "X-KVMD-Passwd: admin")

curl -sk "${AUTH[@]}" "$BASE/api/streamer" | jq '.result.streamer.source'
```
*Expected Output:*
```json
{
  "online": true,
  "captured_fps": 50,
  "resolution": {
    "width": 1920,
    "height": 1080
  }
}
```
> [!IMPORTANT]
> If `online` reads `false`, verify that the target host's GPU is outputting an active video signal (not in standby mode) and that the HDMI cables are seated securely.

### 2. HID Emulation Status Check
Query the mouse/keyboard emulation endpoints:
```bash
curl -sk "${AUTH[@]}" "$BASE/api/hid" | jq '.result'
```
*Expected Output:*
```json
{
  "online": true,
  "keyboard": {
    "online": true
  },
  "mouse": {
    "online": true
  }
}
```

### 3. ATX Power Relay Status Check (If Connected)
Query the motherboard button relays:
```bash
curl -sk "${AUTH[@]}" "$BASE/api/atx" | jq '.result'
```
*Expected Output:*
```json
{
  "power": {
    "online": true
  },
  "reset": {
    "online": true
  }
}
```

---

## 4. Rollback & Troubleshooting

### Switch Control Fails (Ports Won't Switch via API):
- Verify that the custom firmware was successfully flashed: see [Firmware Updating](https://docs.pikvm.org/switch/#firmware-updating). If stock firmware remains, the switch will ignore UART switching bytes.
- Confirm the CH340 controller registers in kernel logs:
  ```bash
  dmesg | grep CH344
  ```
  Ensure the serial bridge maps to `/dev/kvmd-switch` (or standard `/dev/ttyUSB0`).

### Capture Flickering / Signal Resets:
- If switching ports causes target hosts to drop display targets or rearrange desktop windows, verify that `ignore_hpd_on_top` is set to `true` and that the `kvmd` service restarted successfully:
  ```bash
  systemctl status kvmd | grep "Active: active (running)"
  ```
