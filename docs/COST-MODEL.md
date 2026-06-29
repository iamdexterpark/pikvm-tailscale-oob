# PiKVM over Tailscale — Cost Model

> **Business case first.** The economic argument in full; the README carries only the summary.
> Two cost planes matter, and conflating them hides the real levers — so keep them separate:
>
> 1. **Infrastructure plane** — what it costs to *own and run the appliance*: hardware CapEx
>    (amortized), and power. This is where the DIY-PiKVM-vs-commercial thesis is won.
> 2. **Operational plane** — what it costs to *operate the recovery capability*: one-time build/flash
>    toil, and the marginal cost of an actual recovery event. There is no per-use meter here — the
>    appliance is self-hosted on a self-managed mesh — so this plane is dominated by a one-time build
>    cost and the value of each avoided dispatch.
>
> Every figure carries a `Source` (vendor/list pricing URL or a stated assumption). Unsourced
> numbers are a draft, not a deliverable. **All dollar figures are order-of-magnitude estimates for a
> single reference appliance; component prices vary by market and condition. Treat them as a sizing
> model, not a quote.**

---

## 1. Infrastructure Plane — Own-and-Run the Appliance

The thesis: a DIY PiKVM v3 delivers **enterprise-grade, instant-TTR out-of-band control for ~$180
one-time and ~$0 recurring** — a fraction of a commercial KVM-over-IP node, and it breaks even
against a single smart-hands dispatch.

### 1.1 Hardware (CapEx) — the bill of materials

| Item | Component | Est. cost | Source / assumption |
|---|---|---|---|
| SBC | Raspberry Pi 4 Model B (4–8 GB) | ~$55–75 | [raspberrypi.com](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/) list bands |
| KVM HAT | PiKVM v3 HAT | ~$70–90 | [pikvm.org](https://pikvm.org) / [shop.hipi.io](https://shop.hipi.io) bands |
| Storage | A2 microSD 32 GB+ (or USB 3.0 SSD) | ~$10–15 | generic retail |
| PSU | Official 5V/3A+ supply | ~$10 | mandatory — undervoltage throttles the encoder |
| Cooling | Active heatsink + PWM fan case | ~$15 | required for sustained H.264 encode |
| Cables | HDMI + USB-A→USB-C OTG, per target | ~$5–10/target | dedicated signal path per host |
| **Appliance subtotal** | (excl. switch) | **~$180** | the recovery plane, one-time |

**Optional multi-host scaling:**

| Item | Component | Est. cost | Source |
|---|---|---|---|
| KVM switch | 4-port HDMI/USB (PiKVM-compatible) | ~$60–120 | [PiKVM Switch](https://docs.pikvm.org/switch/) |
| Multiport extender | Switch Multiport Extender | varies | [Hipi Shop Extender](https://shop.hipi.io/product/pikvm-switch-multiport-extender) |

> One appliance + one switch fans a single capture card across up to 4 targets — the per-target
> marginal cost is a cable, not another KVM. ([ADR-0003](adr/0003-hardware-switch-over-software-mux.md))

### 1.2 The core comparison — DIY vs. the alternatives

| Dimension | Commercial enterprise KVM (Raritan/Lantronix/Aten) | [PiKVM V4 Plus](https://shop.hipi.io/product/pikvm-v4-plus) | Smart-hands dispatch | **DIY PiKVM v3 + Tailscale (this design)** |
|---|---|---|---|---|
| Initial CapEx | ~$600–1,800/node | **~$350** | $0 | **~$180** |
| Recurring OpEx | ~$150/yr support/license | $0 | $250–500 per event | **$0** |
| Time to resolution | instant | instant | 4–48 h (dispatch lag) | **instant** |
| Coverage on cardless hosts | yes | yes | yes (escorted) | **yes** (HDMI/USB/ATX/PDU) |
| Control / lock-in | proprietary, licensed | open | none | **open (MIT/GPL), self-managed** |

> *Source / assumptions:* commercial KVM-over-IP street pricing and support-fee bands are
> order-of-magnitude industry figures; PiKVM V4 Plus list ~$350 ([shop.hipi.io](https://shop.hipi.io/product/pikvm-v4-plus));
> smart-hands $250–500/visit is a typical remote-hands rate band; DIY subtotal from §1.1. All bands,
> not quotes. ([ADR-0007](adr/0007-pikvm-over-commercial-oob.md))

### 1.3 Power (OpEx)

| Scenario | Avg draw | Monthly kWh | Monthly $ @ $0.15/kWh |
|---|---|---|---|
| PiKVM idle (no active stream) | ~3 W | ~2.2 kWh | **~$0.3** |
| PiKVM under 1080p25 H.264 encode | ~6–7 W | ~5 kWh | **~$0.75** |

> *Source / assumption:* Pi 4 draw figures are standard published bands (idle ~2.7 W, load higher);
> $0.15/kWh is a generic blended rate — substitute your tariff. Power is a rounding error; the point
> is a **silent, fanned, always-on recovery appliance** that costs cents/month to leave running.

### 1.4 Infra-plane rollup (amortized)

| Class | Monthly est. | Basis |
|---|---|---|
| Appliance hardware (3-yr straight-line) | ~$5 | $180 / 36 mo |
| Power | ~$0.75 | §1.3 |
| **Infra subtotal** | **~$6/mo** | the entire floor for an always-on OOB recovery plane |

---

## 2. Operational Plane — Operate the Recovery Capability

> The infra floor (§1) is trivially cheap; the *operating* cost is a **one-time build/flash toll** and
> then the **value realized per recovery event** — not a recurring meter.

### 2.1 Build toil (the one-time tax)

The unit of work is "bring the appliance from parts to a reachable, tuned console."

| Phase | Class | Time (assumed) | Why |
|---|---|---|---|
| Flash OS + assemble HAT/cabling | manual | ~30–45 min | physical, one-shot |
| Flash KVM switch firmware (UART) | manual | ~20–30 min | serial flash; one-time per switch |
| Tailnet enrollment + ACL tag | scripted | ~5 min | `tailscale up --advertise-tags=tag:oob` |
| Streamer tuning to target refresh | config | ~10 min/target | integer-divisor fps + GOP ([ADR-0004](adr/0004-source-synchronized-encoding.md)/[0005](adr/0005-locked-gop-cadence.md)) |

**Toil model:** one-time stand-up ≈ **~$100–150** of engineer time at a $75/hr loaded rate. It does
**not recur** — once built, the appliance is a fixed asset, not a meter.

### 2.2 The recovery-event value (the asymmetric payoff)

This is the line item the whole design is built around — and it runs *negative* on cost (it saves
money) every time it's used.

| Factor | Without OOB (smart-hands) | **With this appliance** |
|---|---|---|
| Recovery action | schedule + dispatch a technician | open the console from anywhere, reset via ATX/PDU |
| MTTR | 4–48 h | **< 5 min** |
| Cost per event | $250–500 | **~$0** (sunk appliance) |
| Break-even | — | **the appliance pays for itself on the first avoided dispatch** |

### 2.3 Steady-state ops (the small, real line items)

- **Mesh:** $0 — self-hosted overlay; no per-seat/per-node fee at this scale.
- **Monitoring:** the bundled scripts (`health-snapshot.sh`, `path-probe.sh`) poll the kvmd telemetry
  API; wall-clock attention, not dollars. ([OPERATIONS Day-2](OPERATIONS.md#day-2--operate-run-it-like-it-matters))
- **Operator attention:** best-effort for a single appliance; the recovery plane is idle until needed.

### 2.4 Operational-plane rollup

| Line item | Cost | Lever |
|---|---|---|
| Build/flash (one-time) | ~$100–150 toil | tight gated runbook; minimize manual phase |
| Per recovery event | **~$0** + < 5 min | replaces a $250–500 dispatch |
| Steady-state ops | ~$0 marginal | self-hosted mesh, scripted telemetry |
| **Operational net** | **dominated by the one-time build; each use saves money** | the appliance is an asset, not a meter |

---

## 3. ⚠️ Operational Cost Traps (read before deploying)

Each is a control the design addresses, not a disclaimer.

- **Undervoltage silently throttles the encoder.** A weak PSU or thin cable drops the SoC clock and
  you get packet/video dropouts that look like a network problem. **Use the official 5V/3A+ supply**;
  the health script surfaces throttle flags (`!= 0x0`). ([LLD §12](LLD.md#12-operational-health-baselines))
- **Thermal load is real under sustained encode.** H.264 WebRTC encoding heats the SoC; without an
  active heatsink it throttles. **Active cooling is mandatory, not optional.**
- **DERP relay is a throughput tax.** If the mesh can't punch a direct P2P path, it falls back to a
  relay and the 1080p stream degrades. **Treat a persistent DERP path as a finding** — `path-probe.sh`
  flags it — and fix the NAT/firewall rather than living on the relay. ([HLD §6](HLD.md#6-network-nat-traversal-mechanics))
- **Edits without `rw` silently revert.** The read-only rootfs ([ADR-0006](adr/0006-read-only-rootfs.md))
  means a config change made outside the `rw … ro` envelope vanishes on reboot — and you discover it
  at the worst time. **Always wrap persistent edits in `rw`/`ro`.**
- **SD-card wear on a write-active config.** Defeating read-only root to "make life easier" trades the
  appliance's power-loss durability for flash wear. **Keep root read-only by default.**
- **An un-tested recovery path isn't a recovery path.** ATX-relay wiring or smart-PDU API access that
  nobody has exercised may not work when the host is actually frozen. **Test the power-cycle path at
  build time**, not during an incident.

**Guardrails to wire in:**
- Official PSU + active cooling **verified at build** (throttle flag `0x0` under load).
- `path-probe.sh` check that the operator path is **direct P2P, not DERP**.
- Every config-change runbook uses the **`rw` … `ro` envelope**.
- **Power-cycle path (ATX or PDU) tested** before the appliance is trusted in production.

---

## 4. Total Cost of Ownership (rollup)

| Plane | Cost | Driver | Lever |
|---|---|---|---|
| Infrastructure | ~$6/mo amortized (+ ~$180 sunk CapEx, +switch if multi-host) | hardware + power | DIY PiKVM beats commercial KVM-over-IP on cost-per-capability by ~5–10× |
| Operational | ~$100–150 one-time build toil; ~$0/event thereafter | build/flash tax | tight gated runbook; self-hosted mesh; reusable across the fleet via one switch |
| **TCO** | enterprise-grade, instant-TTR OOB for **~$180 one-time, ~$6/mo to run** | | |

*ROI / break-even:* against smart-hands dispatch, the appliance **pays for itself on the first
avoided visit** ($250–500). Against a commercial KVM-over-IP node ($600–1,800 + license), it delivers
the same instant-TTR, cardless-host coverage for **~$180 and no recurring fee** — open, self-managed,
no lock-in. The premium you pay is a one-time build and the discipline of testing the power-cycle path
once. ([ADR-0007](adr/0007-pikvm-over-commercial-oob.md))
