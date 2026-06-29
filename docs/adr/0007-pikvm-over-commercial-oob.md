# ADR-0007 — PiKVM v3 + Pi 4 over commercial OOB or smart-hands dispatch

**Status:** Accepted
**Date:** 2026-06-21
**Deciders:** Platform Engineering
**Related:** [HLD §1](../HLD.md#1-business-case--roi), [COST-MODEL §1](../COST-MODEL.md#1-infrastructure-plane--own-and-run-the-appliance), [LLD §1](../LLD.md#1-bill-of-materials)

---

## Context and Problem Statement

A host can lock up below the OS, and remote command-line and desktop tools are useless there. Some
recovery plane must exist. The target fleet (mini-PCs, Apple Silicon Mac minis) lacks IPMI/iLO/iDRAC,
so management cards aren't an option on the hosts themselves. **What provides the out-of-band recovery
capability, and at what cost?**

## Decision Drivers

- **D1 — Time to resolution:** how fast a frozen host is recovered.
- **D2 — Capital + operating cost:** CapEx and any recurring license/dispatch spend.
- **D3 — Coverage:** works on hosts with no management card.
- **D4 — Control / lock-in:** open vs. proprietary, self-managed vs. vendor-gated.

## Considered Options

### Option A — Commercial enterprise KVM-over-IP (Raritan / Lantronix / Aten)
- ➕ Turnkey, instant TTR, vendor support (D1).
- ➖ ~$600–1,800/node CapEx plus recurring support/license fees (D2).
- ➖ Proprietary, often requiring DMZ/NAT gymnastics and client licenses (D4).
- **Verdict: rejected — enterprise pricing and lock-in for a small edge/home-lab footprint.**

### Option B — "Smart hands" / on-site dispatch
- ➕ Zero CapEx; no appliance to own (D2 capital).
- ➖ $250–500 per dispatch and 4–48h TTR — a frozen host stays down for hours-to-days (D1, D2 opex).
- **Verdict: rejected — TTR and per-event cost are both unacceptable for routine recovery.**

### Option C — PiKVM V4 Plus (integrated commercial appliance)
- ➕ Pre-assembled, instant TTR, open platform (D1, D3, D4).
- ➖ ~$350/node — fine, but more than the DIY build for the same core capability (D2).
- **Verdict: rejected for this build — viable upgrade path, but the DIY v3 meets the need cheaper.**

### Option D — DIY PiKVM v3 on Raspberry Pi 4 + physical KVM switch  ✅
- ➕ Firmware-level capture/HID/power below the OS; instant TTR from anywhere (D1).
- ➕ ~$180 one-time CapEx, $0 recurring — self-hosted mesh, no licenses (D2).
- ➕ Works on cardless hosts (HDMI + USB + ATX/PDU); covers the whole fleet via one switch (D3).
- ➕ Fully open (MIT/GPL), self-managed, no vendor gate (D4).
- ➖ DIY assembly + firmware flashing; capped at 1080p25–30 console use (not media/4K).
- **Verdict: chosen — enterprise-grade TTR at hobbyist CapEx, no lock-in, breaks even on event #1.**

## Decision

Build the OOB plane on a DIY PiKVM v3 (Raspberry Pi 4) with a physical KVM switch and Tailscale mesh.
Treat the [PiKVM V4 Plus](https://shop.hipi.io/product/pikvm-v4-plus) as the documented upgrade path
if integration/scale later justifies the higher CapEx.

## Consequences

**Positive**
- Instant remote recovery at ~$180 one-time and $0 recurring; pays for itself on the first avoided
  dispatch.

**Negative / Risks accepted**
- DIY assembly + switch-firmware flashing is a one-time bring-up tax (runbooks cover it); the Pi-4
  class encoder caps the console at 1080p25–30 — acceptable, it's a management console, not a media
  feed.

## Revisit If

- Node count or integration needs justify the V4 Plus, or targets gain native IPMI/iDRAC making an
  external capture appliance unnecessary.
