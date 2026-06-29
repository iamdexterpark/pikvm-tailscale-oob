# ADR-0008 — OpenSSH over the tailnet for automation, not Tailscale-SSH

**Status:** Accepted
**Date:** 2026-06-29
**Deciders:** Platform Engineering
**Related:** [ADR-0002](0002-tailscale-mesh-over-port-forward.md), [ADR-0006](0006-read-only-rootfs.md), [LLD §9](../LLD.md#9-tailscale-provisioning--acls), [Runbook 03](../runbooks/profile-pikvm-v3-pi4/03-tailscale-oob/RUNBOOK.md)

---

## Context and Problem Statement

The tailnet ([ADR-0002](0002-tailscale-mesh-over-port-forward.md)) gives the appliance two SSH paths
*simultaneously*, and they behave very differently — a fact that only becomes obvious when you try to
script against it (confirmed live while rotating the appliance's web credentials):

1. **Tailscale-SSH** — `tailscaled` advertises the SSH capability and **intercepts connections to the
   tailnet IP `:22`**. Under a check-mode ACL it forces an interactive browser auth
   (`# Tailscale SSH requires an additional check. To authenticate, visit: https://login.tailscale.com/a/<token>`).
   That is **non-scriptable**: a headless `ssh root@<tailnet-ip>` hangs until a human completes the web
   flow, then times out.
2. **OpenSSH** — the real `sshd` listens on `0.0.0.0:22` independently. Reached by **key, with
   `BatchMode=yes`**, it is clean, deterministic, and fully scriptable.

For the *out-of-band recovery path* specifically, this matters more than for a normal host: **OOB must
work precisely when other things are broken** — including when the tailnet control plane is degraded or
no human is available to complete a browser check. **Which SSH mechanism should automation depend on?**

## Decision Drivers

- **D1 — Scriptable:** cred rotation, health checks, config converge, and agent-driven ops must run
  headless, with no interactive prompt.
- **D2 — Recovery-grade independence:** the OOB path should not add a hard dependency on a third-party
  control plane or a browser session to function.
- **D3 — Identity-bound + auditable:** per-identity, key-based, revocable.
- **D4 — Keep a human convenience path:** interactive operators may still want the zero-key web check.

## Considered Options

### Option A — Tailscale-SSH as the primary SSH path
- ➕ No key distribution; identity is the tailnet login (D3); zero-config for humans (D4).
- ➖ Check-mode forces a browser flow — **non-scriptable** (D1); adds a control-plane + browser
  dependency to the recovery path (D2).
- **Verdict: rejected as the automation path — fatal for headless OOB; kept for human convenience only.**

### Option B — OpenSSH over the tailnet, operator key, `BatchMode`  ✅
- ➕ Deterministic, headless, key-only (D1); self-contained — one private key, no external auth
  round-trip, works even if the coordination plane is flaky (D2); per-key, revocable, audit-friendly
  (D3). Tailscale-SSH can stay enabled in parallel for interactive humans (D4).
- ➖ Operator must manage an SSH keypair (acceptable; it's one ed25519 key).
- **Verdict: chosen for all automation.**

### Option C — Public/LAN password SSH
- ➕ Simplest break-glass.
- ➖ Shared secret, not identity-bound (D3); weak on the most dangerous endpoint.
- **Verdict: rejected as primary; retained only as a break-glass fallback behind the key.**

## Decision

**All programmatic SSH to the appliance uses OpenSSH with an operator key (`BatchMode=yes`),** reached
over the tailnet (or the dedicated OOB LAN address on-site). Automation must **not** depend on
Tailscale-SSH. Tailscale-SSH may remain enabled for interactive human convenience, but no script, cron,
config-management run, or agent action may rely on it.

- Canonical automation path: `ssh -i <operator_key> -o BatchMode=yes root@<oob-address>`.
- Optional hardening: disable Tailscale-SSH on the node (`tailscale set --ssh=false`) to make OpenSSH the
  only `:22` answerer and remove the ambiguity entirely. Deferred by default — keeping it gives a
  no-key human fallback, and the canonical path already bypasses it.

## Consequences

**Positive**
- Headless cred rotation / health checks / converge work first-try; the recovery path doesn't hinge on
  a browser flow or the control plane being healthy.

**Negative / Risks accepted**
- An operator keypair must be provisioned and rotated (one ed25519 key; standard hygiene).
- Running both SSH mechanisms in parallel is mildly confusing — mitigated by documenting the canonical
  path and the optional `--ssh=false` hardening.

## Revisit If

- Tailscale ships a non-interactive (true headless, no-browser) auth mode suitable for automation, or
  the appliance's recovery model changes such that control-plane dependence is acceptable.
