# Runbook 08 — Cold Spare & Break-Fix

> **Target Environment**
> | | |
> |---|---|
> | **Deployment profile** | `_common` (profile-independent) |
> | **Substrate** | Raspberry Pi 4 + PiKVM v3 HAT + Arch-ARM PiKVM OS |
> | **Cloud / external services** | Tailscale coordination plane; smart-PDU API (if used) |
> | **Identity model** | kvmd local credentials; tailnet identity + `tag:oob` ACL |
> | **What changes under a different profile** | a different appliance class re-flashes per its own build runbooks; the spare/restore *logic* is identical |

**Goal:** restore the OOB recovery plane after the appliance itself degrades or fails — by remediating
in place, or by swapping in a pre-staged cold spare.
**Time:** ~10–20 min (swap) · **Risk:** low · **Reversible:** yes

## Prerequisites

- A **pre-staged cold spare** is the design's resilience lever — a second flashed Pi + HAT on the
  shelf, OR a saved config bundle (`override.yaml`, switch mappings, tailnet ACL) for a fast rebuild.
- Access to the tailnet admin console (to deauthorize the failed node and authorize the spare).

## Steps

### 1. Triage — is this a remediation or a swap?
Use [05-troubleshooting](../05-troubleshooting/RUNBOOK.md) to classify. Remediate in place if it's a
soft fault (throttle, DERP fallback, reverted config). Swap if the SBC/HAT/SD is dead.

### 2a. Remediate in place (soft faults)
```bash
# Undervoltage / throttle: replace PSU or cable, then confirm flags clear
# (see health-snapshot.sh) — expect 0x0
rw
# re-apply any config that reverted because it was edited outside an rw/ro envelope
ro
systemctl restart kvmd
```

### 2b. Swap in the cold spare (hard failure)
```bash
# 1) Deauthorize the failed node in the tailnet admin console (remove tag:oob device).
# 2) Move the microSD/SSD to the spare Pi if the card is healthy; else flash the spare
#    and restore the saved config bundle.
# 3) Re-cable HDMI/USB/ATX from the switch to the spare appliance.
# 4) Enroll the spare on the tailnet:
rw
tailscale up --hostname=oob-kvm --advertise-tags=tag:oob --accept-dns=true
ro
```

### 3. Reconfirm the recovery path
Select each switch port; verify capture + HID; **test a power-cycle** on a non-production target.

## Verification

```bash
# Appliance healthy and reachable
./scripts/health-snapshot.sh        # temp normal, throttling 0x0, CPU sane
./scripts/path-probe.sh             # DIRECT path (not DERP), jitter < 5 ms local
# Mesh node present and tagged oob in the tailnet admin console
# A test reset visibly cycles a target host
```

Success criterion: console reachable over the mesh, throttle flags `0x0`, direct P2P path, every
switch port selects its target, and a power-cycle works.

## Rollback

The swap is non-destructive to the targets. If the spare misbehaves, re-seat the original media or
re-restore the config bundle; nothing here touches target-host state.

## Notes / Gotchas

- **Stage the spare *before* you need it.** An un-staged spare turns a 10-minute swap into a 45-minute
  build during an incident ([COST-MODEL §3](../../../../docs/COST-MODEL.md#3-️-operational-cost-traps-read-before-deploying)).
- **Always deauthorize the failed node** in the tailnet — a stale authorized `tag:oob` device is a
  live security loose end.
- Edits made without the `rw … ro` envelope revert on reboot ([ADR-0006](../../../../docs/adr/0006-read-only-rootfs.md)).
