# Runbooks

Procedures, split by **deployment profile** (PLAYBOOK §5b). Profile-specific build steps live under
`profile-<appliance>/`; profile-independent operations live under `_common/`. This mirrors the
operating model in [OPERATIONS.md](../OPERATIONS.md) — the lifecycle state machine maps each
transition to one of these runbooks.

Start from [`RUNBOOK-template.md`](RUNBOOK-template.md); every runbook declares its **Target
Environment** up front.

## Primary profile — [`profile-pikvm-v3-pi4/`](profile-pikvm-v3-pi4/README.md)

DIY PiKVM v3 HAT on a Raspberry Pi 4. Run `01 → 04` in order for a fresh build.

| # | Runbook | Purpose |
|---|---|---|
| 01 | [Raspberry Pi Provisioning](profile-pikvm-v3-pi4/01-raspberry-pi-provisioning/RUNBOOK.md) | Flash, first boot, read-only rootfs, base hardening |
| 02 | [PiKVM Install](profile-pikvm-v3-pi4/02-pikvm-install/RUNBOOK.md) | Wiring, HDMI/USB switch, first capture + HID |
| 03 | [Tailscale OOB](profile-pikvm-v3-pi4/03-tailscale-oob/RUNBOOK.md) | Join tailnet, ACLs, tags, SSH posture, MagicDNS |
| 04 | [Streamer Tuning](profile-pikvm-v3-pi4/04-streamer-tuning/RUNBOOK.md) | Source-matched H.264 fps/GOP for reliable interactive use |

## Profile-independent — [`_common/`](_common)

Apply regardless of appliance class.

| # | Runbook | Purpose |
|---|---|---|
| 05 | [Troubleshooting](_common/05-troubleshooting/RUNBOOK.md) | Symptom → cause → fix playbook & API diagnostics |
| 08 | [Cold Spare & Break-Fix](_common/08-cold-spare-and-break-fix/RUNBOOK.md) | Remediate in place or swap the pre-staged spare |
| 09 | [Decommission](_common/09-decommission/RUNBOOK.md) | Deauthorize mesh identity, revoke creds, wipe media |

> Numbering leaves gaps (06–07) intentionally, reserving slots for future `_common` operations
> (e.g. coordinated OS/firmware upgrade) without renumbering the existing set.

## Adding a profile

A different OOB appliance class (e.g. PiKVM **V4 Plus**, or a generic IP-KVM) is a **new profile**,
not a mutation of the primary one — copy `profile-pikvm-v3-pi4/` to `profile-<appliance>/`, reuse
`_common/` unchanged, and re-author only the build/wiring/tuning steps. The
[LLD Environment Profiles](../LLD.md#13-environment-profiles) section defines the axes a new profile
must specify; a material target switch earns its own ADR.

**Conventions**
- All IPs / hostnames / creds are **placeholders** — replace with yours.
- `rw` / `ro` = PiKVM helper aliases to remount the rootfs read-write / read-only. Persistent changes
  require `rw` first, then `ro` to re-seal ([ADR-0006](../adr/0006-read-only-rootfs.md)).
- The kvmd **HTTP API** is the preferred automation surface (no SSH dependency).
- Operating model, monitoring, and break-fix tiers live in [OPERATIONS.md](../OPERATIONS.md);
  economics in [COST-MODEL](../COST-MODEL.md).
