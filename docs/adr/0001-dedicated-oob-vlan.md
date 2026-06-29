# ADR-0001 — Dedicated out-of-band VLAN over a flat management network

**Status:** Accepted
**Date:** 2026-06-21
**Deciders:** Platform Engineering
**Related:** [HLD §4.1](../HLD.md#4-principles), [LLD §4](../LLD.md#4-network--ip-plan), [LLD §10](../LLD.md#10-router-acl-specifications)

---

## Context and Problem Statement

The recovery plane controls hosts at the firmware level — BIOS/EFI keystrokes, power cycling, raw
console. A device that can hard-reset every node in the rack is the single most security-sensitive
endpoint on site. If a compromised user laptop, IoT sensor, or guest device can reach the PiKVM's web
console, the blast radius is the whole fleet. **Which network segment does the OOB appliance live
on?**

## Decision Drivers

- **D1 — Blast-radius containment:** a compromise elsewhere on the LAN must not reach the KVM.
- **D2 — Lateral-movement denial:** the KVM itself must not become a pivot into user networks.
- **D3 — Determinism:** the appliance must be addressable predictably for scripts and runbooks.
- **D4 — Simplicity:** no heavyweight NAC/802.1X stack for a single-operator edge site.

## Considered Options

### Option A — Flat LAN, KVM on the general subnet
- ➕ Zero network config; plug in and go (D4).
- ➖ Every device on the LAN can reach the firmware-control plane of every host (D1).
- ➖ A compromised host pivots straight to the KVM and back out (D2).
- **Verdict: rejected — co-locating the most dangerous endpoint with the least-trusted devices.**

### Option B — Per-port 802.1X / NAC enforcement
- ➕ Strong identity-bound port security (D1, D2).
- ➖ A RADIUS/NAC stack is disproportionate operational weight for one appliance (D4).
- **Verdict: rejected — enterprise machinery for a single-operator footprint.**

### Option C — Dedicated, isolated OOB VLAN with L3 ACLs  ✅
- ➕ The KVM sits in its own broadcast domain (`VLAN 20`); no L2 adjacency from user/IoT/guest (D1).
- ➕ Router SVI ACLs deny `OOB → general` so the KVM can't be a pivot, and `user/IoT/guest → OOB`
   so nothing reaches the console except admins and the mesh (D2).
- ➕ Static `/27` with a fixed appliance address makes scripting deterministic (D3).
- ➖ Requires a managed switch/router with VLAN + L3 ACL support — assumed present at an edge rack.
- **Verdict: chosen — segment isolation is the cheapest, strongest control available.**

## Decision

Place the PiKVM on a dedicated, isolated management VLAN (`VLAN 20`, `10.0.20.0/27`, appliance at
`10.0.20.7`) behind a router SVI that **default-denies** between the OOB segment and all user planes,
permitting only admin-device and Tailscale-mesh transit to `:443`.

## Consequences

**Positive**
- A compromise of any user/IoT/guest device has no path to the firmware-control plane.
- The KVM cannot be used as a lateral-movement pivot back into the user networks.

**Negative / Risks accepted**
- Depends on a managed switch/router; a consumer flat-network site can't enforce this — documented as
  a prerequisite in the [LLD §10 router ACLs](../LLD.md#10-router-acl-specifications).

## Revisit If

- The site moves to a full zero-trust microsegmentation fabric (per-device policy) that makes a
  dedicated VLAN redundant, or the OOB plane must span multiple physical sites (then mesh-only with
  no local SVI).
