# ADR-0006 — Read-only root filesystem for power-loss durability

**Status:** Accepted
**Date:** 2026-06-21
**Deciders:** Platform Engineering
**Related:** [HLD §4.6](../HLD.md#4-principles), [LLD §5](../LLD.md#5-operating-system--filesystem)

---

## Context and Problem Statement

The appliance lives at an edge site on an SD card or USB SSD, exposed to brownouts and sudden power
cuts — the exact conditions it exists to recover *other* hosts from. A write-active filesystem
interrupted mid-write corrupts, and a recovery appliance that won't boot after a power blip is worse
than useless: it fails precisely when the site is already in trouble. **How does the appliance
survive uncontrolled power loss and still boot?**

## Decision Drivers

- **D1 — Boot reliability after power loss:** must come back clean after an unclean shutdown.
- **D2 — Storage longevity:** minimize flash wear on SD/USB media.
- **D3 — Operability:** config changes must still be possible when intended.

## Considered Options

### Option A — Standard read-write root
- ➕ Edit anything anytime; zero ceremony (D3).
- ➖ A power cut mid-write corrupts the rootfs; the appliance may not boot (D1).
- ➖ Continuous writes wear the flash (D2).
- **Verdict: rejected — trades the one property an edge recovery appliance must have.**

### Option B — Full immutable image (no in-place mutability at all)
- ➕ Strongest integrity guarantee (D1, D2).
- ➖ Every change means a re-image cycle — too heavy for routine per-target tuning (D3).
- **Verdict: rejected — operability cost too high for a single-appliance, single-operator site.**

### Option C — Read-only root by default with explicit `rw`/`ro` elevation  ✅
- ➕ The rootfs is read-only at runtime, so a power cut can't corrupt it; it boots clean (D1).
- ➕ No steady-state writes → minimal flash wear (D2).
- ➕ A deliberate `rw` helper unlocks edits, `ro` re-seals — changes are intentional and bounded (D3).
- ➖ The `rw`/`ro` dance is an easy footgun: edits made without `rw` silently revert on reboot.
- **Verdict: chosen — durability by default, mutability on demand.**

## Decision

Mount root (`/`) and boot (`/boot`) **read-only by default**; require the explicit `rw` helper to make
persistent changes and `ro` to re-seal. The default state of the appliance is immutable-at-runtime.

## Consequences

**Positive**
- The appliance survives uncontrolled power loss and boots cleanly; flash wear is minimized.

**Negative / Risks accepted**
- Changes made without first running `rw` appear to succeed but revert on reboot — a known footgun,
  called out in the LLD and every runbook that edits config (the `rw … ro` envelope is mandatory).

## Revisit If

- The appliance moves to power-protected storage with journaled integrity (UPS + enterprise SSD)
  where read-write root no longer risks corruption, or a fully immutable image pipeline is adopted.
