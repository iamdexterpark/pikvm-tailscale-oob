# ADR-0003 — Hardware-level physical KVM switch over software / hypervisor multiplexing

**Status:** Accepted
**Date:** 2026-06-21
**Deciders:** Platform Engineering
**Related:** [HLD §4.3](../HLD.md#4-principles), [HLD §8](../HLD.md#8-fate-sharing-boundaries), [LLD §8](../LLD.md#8-switch-serial-uart-interface)

---

## Context and Problem Statement

A single PiKVM capture card must control multiple headless hosts. The whole reason this control plane
exists is to reach a host **when its OS is dead** — kernel panic, hung bootloader, lost network. So
the multiplexing layer that selects between hosts must itself survive the failure of any host it
points at. **How is one console fanned out across several targets without inheriting their failure
modes?**

## Decision Drivers

- **D1 — Fate-sharing independence:** selecting/holding a target must not depend on that target's OS.
- **D2 — Below-the-OS reach:** must capture BIOS/EFI and inject HID before any OS loads.
- **D3 — Determinism:** target selection must be repeatable and scriptable.
- **D4 — Cost / simplicity:** no per-target licensing or agent sprawl.

## Considered Options

### Option A — Software KVM / remote-desktop agents per host
- ➕ No extra hardware; cheap to add a host (D4).
- ➖ Dies exactly when needed — a panicked or pre-boot host runs no agent (D1, D2).
- **Verdict: rejected — an in-OS agent cannot manage a host whose OS is down.**

### Option B — Hypervisor / IP-KVM-over-host integration
- ➕ Centralized console switching in software (D3).
- ➖ The switcher fate-shares with the host platform; if the host hangs, the switch hangs (D1).
- ➖ Assumes a virtualization layer the bare-metal targets don't run (D2).
- **Verdict: rejected — reintroduces the fate-sharing the OOB plane exists to avoid.**

### Option C — Driverless physical HDMI/USB KVM switch, serially controlled  ✅
- ➕ Pure hardware path: HDMI capture + USB HID multiplexed below any OS — works pre-boot and on a
   dead host (D1, D2).
- ➕ Deterministic port selection over a UART serial frame issued by `kvmd` (D3).
- ➕ One switch covers up to 4 targets; no per-target license or agent (D4).
- ➖ Physical cabling and a firmware-flashed switch — a one-time bring-up cost.
- **Verdict: chosen — the only option that survives the failure it's meant to recover from.**

## Decision

Multiplex with a driverless 4-port HDMI/USB KVM switch, controlled deterministically by `kvmd` over a
USB-to-UART serial interface (CH340, 9600 8N1). Configure `ignore_hpd_on_top: true` so inactive-port
hot-plug-detect pulses never reset the capture bridge.

## Consequences

**Positive**
- The console reaches any target at the firmware level regardless of that target's OS state.
- Target selection is deterministic and scriptable; no software agent to fail.

**Negative / Risks accepted**
- The switch must be flashed with PiKVM-integration firmware and physically cabled — a one-time
  setup tax, documented in the install runbook.

## Revisit If

- Target count outgrows the switch's port budget (cascade extenders, or a larger matrix switch), or
  targets gain real IPMI/iDRAC that makes a shared physical console redundant.
