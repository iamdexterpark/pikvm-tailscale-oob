# ADR-0005 — Locked H.264 GOP cadence for packet-loss self-healing

**Status:** Accepted
**Date:** 2026-06-21
**Deciders:** Platform Engineering
**Related:** [HLD §4.5](../HLD.md#4-principles), [LLD §7](../LLD.md#7-video-streamer-override-schemas), [TUNING.md](../TUNING.md)

---

## Context and Problem Statement

The console rides WebRTC over a mesh that may fall back to a DERP relay, across links that drop
packets. H.264 decoders cannot render until they receive a keyframe (I-frame); the delta frames
between keyframes are useless on their own. If a keyframe is lost and the next one is far away, the
operator stares at a frozen or smeared image until it arrives. **How often does the encoder emit a
self-contained keyframe?**

## Decision Drivers

- **D1 — Fast recovery:** bounded time-to-recover after a lost frame.
- **D2 — Bandwidth efficiency:** keyframes are large; too many wastes the link.
- **D3 — Determinism:** predictable recovery behavior under loss.

## Considered Options

### Option A — Default / unmanaged GOP
- ➕ Maximum compression; keyframes are rare (D2).
- ➖ On packet loss the decoder can freeze for seconds-to-indefinitely awaiting the next I-frame (D1).
- **Verdict: rejected — optimizes bytes at the cost of an unusable stream under loss.**

### Option B — Every-frame keyframes (GOP = 1)
- ➕ Instant recovery (D1).
- ➖ Every frame is a full I-frame — bandwidth explodes, blowing the constrained-link budget (D2).
- **Verdict: rejected — recovery at any cost forfeits the link.**

### Option C — GOP locked to the frame rate (~1-second keyframe interval)  ✅
- ➕ A lost frame self-heals in ≤1 second — bounded, predictable recovery (D1, D3).
- ➕ One keyframe per second is a modest, affordable bandwidth overhead (D2).
- ➖ Slightly higher steady bitrate than an unmanaged GOP — accepted for the recovery guarantee.
- **Verdict: chosen — bounded ≤1s recovery for a small, fixed bandwidth cost.**

## Decision

Lock the H.264 GOP to the configured frame rate (`h264_gop: 25` at 25 fps) so a full keyframe is
emitted every ~1 second, bounding decoder recovery after packet loss to ≤1s.

## Consequences

**Positive**
- The console self-heals within one second of any frame loss — usable over lossy/relayed links.

**Negative / Risks accepted**
- A small, fixed bandwidth premium over an unmanaged GOP — negligible against the usability gain.

## Revisit If

- Transport gains reliable in-order delivery (no loss to recover from), or adaptive GOP control lands
  in the streamer that tunes the interval to measured loss.
