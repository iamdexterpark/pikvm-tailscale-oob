# ADR-0002 — Zero-trust Tailscale mesh over public port-forward / DMZ

**Status:** Accepted
**Date:** 2026-06-21
**Deciders:** Platform Engineering
**Related:** [HLD §4.2](../HLD.md#4-principles), [HLD §6](../HLD.md#6-network-nat-traversal-mechanics), [LLD §9](../LLD.md#9-tailscale-provisioning--acls)

---

## Context and Problem Statement

The operator must reach the console **from anywhere** — the entire point of out-of-band management is
that you're not on site when the host is down. That requires inbound reachability to an appliance
sitting behind a residential/edge NAT. The appliance also happens to be the most dangerous endpoint
on the network ([ADR-0001](0001-dedicated-oob-vlan.md)). **How does a remote operator reach the
console without exposing a firmware-control plane to the public internet?**

## Decision Drivers

- **D1 — Zero public attack surface:** no listener reachable from the open internet.
- **D2 — Reach from anywhere:** works through CGNAT and arbitrary upstream firewalls.
- **D3 — Identity-bound access:** authenticated, per-identity, revocable — not a shared secret.
- **D4 — Low latency:** an interactive console needs direct P2P, not a slow relay, when possible.
- **D5 — Low operational weight:** no self-run VPN concentrator to patch and babysit.

## Considered Options

### Option A — Port-forward `:443` / DMZ the appliance
- ➕ Trivial; works immediately (D2).
- ➖ Publishes a firmware-control plane to internet-wide scanning and brute force (D1, D3).
- ➖ Fails behind CGNAT where no inbound forward is possible (D2).
- **Verdict: rejected — exposing this endpoint publicly is categorically unacceptable.**

### Option B — Self-hosted WireGuard / OpenVPN concentrator
- ➕ No third-party identity dependency; full control (D3).
- ➖ Still needs an inbound public port for the tunnel endpoint — fails under CGNAT (D2).
- ➖ Operator runs, patches, and key-manages a concentrator — ongoing toil (D5).
- **Verdict: rejected — solves exposure but reintroduces an inbound port and run-cost.**

### Option C — Tailscale (WireGuard) mesh overlay with tagged ACLs  ✅
- ➕ **No inbound ports** — the appliance dials out to the coordination plane; nothing is publicly
   reachable (D1).
- ➕ NAT traversal via STUN + UDP hole-punching, with DERP relay fallback through symmetric NATs and
   CGNAT (D2).
- ➕ Access is identity-bound through `tag:oob` ACLs; admins only, centrally revocable (D3).
- ➕ Direct P2P when the path allows — DERP only as fallback, accepted as a latency tax (D4).
- ➕ Managed coordination/DERP plane; no concentrator to run (D5).
- ➖ Introduces a third-party coordination dependency (the tailnet control plane) — accepted; the
   data path is still end-to-end WireGuard, and local-VLAN access survives a coordination outage.
- **Verdict: chosen — portless, identity-bound reach from anywhere with no public attack surface.**

## Decision

Expose **no public listener.** Enroll the PiKVM as a tailnet node tagged `tag:oob`; restrict access
via ACL to `autogroup:admin → tag:oob:443` plus admin SSH. Rely on STUN/hole-punching for direct P2P
and DERP as the fallback transport ([HLD §6](../HLD.md#6-network-nat-traversal-mechanics)). The local
VLAN-20 SVI remains the on-site fallback path independent of the mesh.

## Consequences

**Positive**
- The firmware-control plane has zero internet-facing surface; access is authenticated and revocable.
- Works through CGNAT and hostile upstream firewalls where a port-forward cannot.

**Negative / Risks accepted**
- Dependency on the tailnet coordination plane and DERP relays; mitigated by the independent local
  SVI path and by the fact that established WireGuard sessions are end-to-end (no plaintext at the
  relay). DERP fallback throughput is a documented constraint, not a failure.

## Revisit If

- The site gains a stable static public IP **and** a hardened bastion makes a self-run tunnel
  cheaper than the third-party dependency, or a regulatory constraint forbids the external
  coordination plane.
