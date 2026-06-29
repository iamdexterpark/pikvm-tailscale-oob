# Runbook 09 — Decommission

> **Target Environment**
> | | |
> |---|---|
> | **Deployment profile** | `_common` (profile-independent) |
> | **Substrate** | Raspberry Pi 4 + PiKVM v3 HAT + Arch-ARM PiKVM OS |
> | **Cloud / external services** | Tailscale coordination plane; smart-PDU API (if used) |
> | **Identity model** | kvmd local credentials; tailnet identity + `tag:oob` ACL |
> | **What changes under a different profile** | media-wipe specifics differ by appliance; the *credential/identity teardown* is identical |

**Goal:** retire or repurpose the appliance leaving **zero authorized references** — no orphaned
tailnet node, no live PDU credential, no ACL entry pointing at a dead appliance.
**Time:** ~10 min · **Risk:** medium (destructive to the appliance) · **Reversible:** no

## Prerequisites

- Confirm the appliance is genuinely out of service and no target depends on it for active recovery.
- Tailnet admin access; smart-PDU admin access (if credentials were issued to this node).

## Steps

### 1. Deauthorize the mesh identity (do this first)
```bash
# In the tailnet admin console:
#  - Remove the device from tag:oob
#  - Deauthorize / delete the node
# Leaving an authorized node is the security loose end that matters most.
```

### 2. Revoke external credentials
```bash
# Rotate/revoke any smart-PDU API key or token this appliance held.
# Remove its entry from the OOB VLAN router ACLs (see LLD §10).
```

### 3. Wipe the storage media
```bash
rw
# The read-only rootfs is NOT erasure. Wipe the card/SSD out-of-band:
#   - re-image the media on another machine, or
#   - secure-erase the SD/USB device
# (run from a separate host; this destroys the appliance OS)
```

### 4. Reclaim hardware
Uncable HDMI/USB/ATX from the switch; the Pi + HAT return to the spare pool or are repurposed.

## Verification

```bash
# Tailnet: node no longer appears in the admin console device list
# Router: no ACL entry references the decommissioned appliance address (10.0.20.7)
# PDU: the revoked credential no longer authenticates
```

Success criterion: the node is absent from the tailnet, the OOB VLAN ACLs no longer reference it, and
no external credential it held still authenticates.

## Rollback

None — this is end-of-life. To bring an appliance back, run the profile build runbooks
([profile-pikvm-v3-pi4 01–04](../../profile-pikvm-v3-pi4/README.md)) from scratch.

## Notes / Gotchas

- **Order matters:** deauthorize the mesh identity *before* wiping media, so a half-wiped appliance
  can't linger as an authorized-but-broken tailnet node.
- A `tag:oob` device left authorized after decommission is exactly the kind of orphan a security
  review will (rightly) flag.
