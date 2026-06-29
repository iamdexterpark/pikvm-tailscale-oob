# Runbook 01 — Raspberry Pi Provisioning

Deploy and harden the base Operating System layer on the Raspberry Pi 4 to establish a durable, read-only system foundation.

---

## 1. Goal & Prerequisites
- **Objective:** Provision a Pi 4 with a write-protected Arch ARM PiKVM OS, verify base health, and harden access credentials.
- **Estimated Time:** 20 Minutes
- **Prerequisites:**
  - Raspberry Pi 4 Model B
  - microSD card (A2 rating, ≥32 GB)
  - PiKVM v3 HAT
  - Ethernet cabling (Wi-Fi is blocked by design for OOB reliability)
  - Official 5V/3A+ power supply
- **Reference Documentation:**
  - [Official PiKVM Flashing OS Guide](https://docs.pikvm.org/flashing_os/)
  - [Raspberry Pi Imager Software Downloads](https://www.raspberrypi.com/software/)

---

## 2. Execution Steps

### Step 1: Flash the OS Image
1. Download the [Raspberry Pi Imager Software](https://www.raspberrypi.com/software/) or use your local CLI toolchain.
2. Download the official **PiKVM v3** OS image for the Pi 4 platform from the [Official Flashing OS Guide](https://docs.pikvm.org/flashing_os/).
3. Write the image using the Imager (choose Custom OS and select the downloaded `.img.xz` file) or run `dd`:
   ```bash
   # macOS example: Verify target disk number using `diskutil list` first!
   diskutil unmountDisk /dev/diskN
   sudo dd if=pikvm-v3-hdmi-rpi4-latest.img of=/dev/rdiskN bs=4m status=progress
   sync
   ```
4. Seat the microSD card into the Pi, attach the PiKVM v3 HAT, plug in the Ethernet cable, and connect power.

### Step 2: Remount the Filesystem
The PiKVM filesystem is mounted **read-only (`ro`)** by default. Any change to configs or system states will fail silently on reboot unless you remount the partition read-write:
```bash
rw            # PiKVM alias: remounts root (/) and /boot read-write
# ... perform file edits / service configurations ...
ro            # Reverts the partitions back to read-only
```

### Step 3: Hardening Access Credentials
SSH to the device at its DHCP-leased IP as `root` (default password is `root`). Immediately change the administrative credentials:
```bash
rw

# Set Unix root system password
passwd

# Set KVM Web Console administrative credential
kvmd-htpasswd set admin

# Set system timezone and sync network time
timedatectl set-timezone Etc/UTC
systemctl enable --now systemd-timesyncd

# Disable the fail-looping watchdog (only enable if a battery-backed RTC is installed)
systemctl disable --now kvmd-watchdog

ro
```

---

## 3. SRE Verification Check

Run the following checks to ensure the OS and hardware are healthy:

### 1. Hardware Undervoltage Check
Execute the Broadcom hardware telemetry command:
```bash
vcgencmd get_throttled
```
*Expected Output:*
```
throttled=0x0
```
> [!IMPORTANT]
> Any output other than `0x0` (e.g., `0x50000` or `0x50005`) indicates an active or past undervoltage event. Replace the power supply immediately. A throttled CPU will drop WebRTC frames.

### 2. Time Synchronization Check
Confirm the NTP sync status:
```bash
timedatectl status | grep "System clock synchronized"
```
*Expected Output:*
```
System clock synchronized: yes
```

---

## 4. Rollback & Recovery Strategy

If the Pi fails to boot, encounters persistent network isolation, or corruption is detected:
1. Power down the PiKVM host.
2. Format the microSD card using a card reader and re-run **Step 1 (Flash)**.
3. If corruption repeats, verify the microSD card health using `f3write` / `f3read` to rule out flash blocks degradation.
