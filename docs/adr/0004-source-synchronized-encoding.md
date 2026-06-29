# ADR-0004 — Source-synchronized integer-divisor video encoding

**Status:** Accepted
**Date:** 2026-06-21
**Deciders:** Platform Engineering
**Related:** [HLD §4.4](../HLD.md#4-principles), [LLD §7](../LLD.md#7-video-streamer-override-schemas), [TUNING.md](../TUNING.md)

---

## Context and Problem Statement

The console stream must stay legible and smooth during interactive use — reading boot text, watching
a progress bar, navigating a BIOS menu — on a bandwidth-constrained link, encoded by a Broadcom SoC
H.264 block with finite headroom. The capture source runs at its own native refresh (e.g. 50 Hz).
**At what frame rate does the encoder run relative to the source?**

## Decision Drivers

- **D1 — Visual smoothness:** no judder/stutter during desktop motion.
- **D2 — Encoder headroom:** stay within the SoC's hardware-encode budget (no thermal throttle).
- **D3 — Bandwidth fit:** legible over constrained / relayed links.
- **D4 — Predictability:** deterministic pacing the operator can reason about.

## Considered Options

### Option A — Free-running / max frame rate
- ➕ Maximum apparent fluidity on a fat link (D1, naively).
- ➖ Burns encoder + bandwidth budget for console text that doesn't need it (D2, D3).
- **Verdict: rejected — spends scarce SoC/bandwidth on motion the workload doesn't have.**

### Option B — Arbitrary fixed fps mismatched to source (e.g. 30 fps from a 50 Hz source)
- ➕ Simple constant (D4, naively).
- ➖ A non-integer cadence ratio forces irregular frame drops → visible judder under motion (D1).
- **Verdict: rejected — cadence mismatch is the cause of the stutter, not a fix.**

### Option C — Lock fps to an integer divisor of the source refresh  ✅
- ➕ Integer-divisor pacing (50 Hz → 25 fps) drops frames evenly; motion renders smooth (D1).
- ➕ Half the frames at the same legibility keeps the SoC encoder well within budget (D2).
- ➕ Lower steady bitrate fits constrained/DERP-relayed links (D3).
- ➕ Deterministic, source-derived cadence the operator can predict (D4).
- ➖ Requires knowing/matching each target's output refresh — a per-target tuning step.
- **Verdict: chosen — even pacing is what makes the stream smooth, not raw frame count.**

## Decision

Configure `ustreamer` to lock `desired_fps` to an integer divisor of the target's native source
refresh (e.g. 50 Hz → `desired_fps: 25`), rather than free-running or using a mismatched fixed rate.

## Consequences

**Positive**
- Smooth, judder-free console rendering within the SoC encode budget and on constrained links.

**Negative / Risks accepted**
- Per-target tuning to match source refresh; captured in the streamer-tuning runbook and
  [TUNING.md](../TUNING.md). Derivations and chroma-subsampling math live there.

## Revisit If

- Hardware moves to a capture/encoder with materially more headroom (e.g. PiKVM V4 with a stronger
  encode block) where free-running at source rate is affordable.
