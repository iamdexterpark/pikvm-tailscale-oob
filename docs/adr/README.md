# Architecture Decision Records

These ADRs capture the **load-bearing decisions** behind this repo. The point of an ADR is
not to document the chosen answer — the deliverable already does that — but to record the
**alternatives that were genuinely on the table** and *why they lost*, so the design can be
audited and revisited as conditions change.

Format: lightly-adapted [MADR](https://adr.github.io/madr/). Each record is self-contained:
context → decision drivers → options considered → decision → consequences → revisit-if.
Start from [`0000-template.md`](0000-template.md).

| ADR | Status | Decision | Rejected alternatives |
|---|---|---|---|
| [0001](0001-dedicated-oob-vlan.md) | Accepted | Dedicated isolated OOB VLAN with L3 ACLs | flat LAN (blast radius); 802.1X/NAC (overweight) |
| [0002](0002-tailscale-mesh-over-port-forward.md) | Accepted | Zero-trust Tailscale mesh, no public ports | port-forward/DMZ (public exposure); self-run VPN (inbound port + toil) |
| [0003](0003-hardware-switch-over-software-mux.md) | Accepted | Driverless physical KVM switch, serially controlled | in-OS software KVM (dies with the host); hypervisor mux (fate-sharing) |
| [0004](0004-source-synchronized-encoding.md) | Accepted | Integer-divisor fps locked to source refresh | free-running/max fps (waste); mismatched fixed fps (judder) |
| [0005](0005-locked-gop-cadence.md) | Accepted | H.264 GOP locked to ~1s for ≤1s self-heal | unmanaged GOP (freezes on loss); GOP=1 (bandwidth blowout) |
| [0006](0006-read-only-rootfs.md) | Accepted | Read-only root by default, explicit `rw`/`ro` | read-write root (corruption on power loss); full immutable (too heavy) |
| [0007](0007-pikvm-over-commercial-oob.md) | Accepted | DIY PiKVM v3 on Pi 4 + physical switch | commercial KVM (cost/lock-in); smart-hands (TTR); V4 Plus (CapEx) |
| [0008](0008-openssh-over-tailnet-not-tailscale-ssh.md) | Accepted | OpenSSH + operator key for automation, over the tailnet | Tailscale-SSH (check-mode browser prompt = non-scriptable); password SSH (shared secret) |

> All identifiers, addresses, and hostnames referenced in these records are placeholders,
> consistent with the rest of this sanitized repo.
