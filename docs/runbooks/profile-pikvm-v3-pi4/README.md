# Profile: PiKVM v3 on Raspberry Pi 4 (primary)

This is the **primary deployment profile** — a DIY PiKVM v3 HAT on a Raspberry Pi 4, running the
Arch-ARM PiKVM OS, controlling a fleet through a physical HDMI/USB switch over a Tailscale mesh
([ADR-0003](../../../docs/adr/0003-hardware-switch-over-software-mux.md),
[ADR-0007](../../../docs/adr/0007-pikvm-over-commercial-oob.md)).

The build runbooks `01 → 04` run in order on a fresh appliance. Profile-independent procedures
(troubleshooting, cold-spare/break-fix, decommission) live in [`_common/`](../_common).

| # | Runbook | Leaves you at |
|---|---|---|
| 01 | [Raspberry Pi Provisioning](01-raspberry-pi-provisioning/RUNBOOK.md) | flashed OS, read-only rootfs, base hardening |
| 02 | [PiKVM Install](02-pikvm-install/RUNBOOK.md) | HAT + switch wired, first capture + HID |
| 03 | [Tailscale OOB](03-tailscale-oob/RUNBOOK.md) | tailnet-joined, `tag:oob` ACL, MagicDNS |
| 04 | [Streamer Tuning](04-streamer-tuning/RUNBOOK.md) | fps/GOP locked to target source refresh |

## What this profile owns vs. `_common`

| Concern | This profile | `_common` |
|---|---|---|
| Flash / assemble / wire | ✅ (rb 01–02) | — |
| Mesh enrollment + ACL | ✅ (rb 03) | — |
| Streamer tuning | ✅ (rb 04) | — |
| Symptom→cause→fix | — | ✅ [05-troubleshooting](../_common/05-troubleshooting/RUNBOOK.md) |
| Cold spare / break-fix | — | ✅ [08-cold-spare-and-break-fix](../_common/08-cold-spare-and-break-fix/RUNBOOK.md) |
| Decommission | — | ✅ [09-decommission](../_common/09-decommission/RUNBOOK.md) |

## Extending to another appliance class

A different OOB appliance (e.g. PiKVM **V4 Plus**, or a generic IP-KVM) would be a **new profile**,
not a mutation of this one. The `_common/` runbooks and the Tailscale/ACL model carry over unchanged;
only the build/wiring steps (`01–02`) and the streamer-tuning surface differ. Author a
`profile-<appliance>/` sibling rather than editing this profile in place.
