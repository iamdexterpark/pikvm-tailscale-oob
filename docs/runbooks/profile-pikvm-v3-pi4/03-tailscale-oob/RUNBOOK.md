# Runbook 03 — Tailscale Out-of-Band Setup

Enroll the PiKVM into the private WireGuard mesh overlay (Tailnet) to enable secure remote access without port forwards.

---

## 1. Goal & Prerequisites
- **Objective:** Provision the Tailscale client daemon, tag the node as `tag:oob` to enforce identity access policies, and verify direct peer-to-peer path status.
- **Estimated Time:** 15 Minutes
- **Prerequisites:**
  - Runbooks 01 and 02 completed.
  - An active Tailscale tailnet.
  - Tailnet administrator access to update access control lists (ACLs).

---

## 2. Execution Steps

### Step 1: Install Tailscale & Authenticate Node
1. SSH into the PiKVM host as root.
2. Run the installation script and configure the service to run on startup:
   ```bash
   rw
   curl -fsSL https://tailscale.com/install.sh | sh
   systemctl enable --now tailscaled
   ```
3. Join the tailnet, tag the node, and request system DNS integration:
   ```bash
   tailscale up \
     --hostname=oob-kvm \
     --advertise-tags=tag:oob \
     --accept-dns=true
   ro
   ```
4. Authenticate the node by copying the generated URL into a browser session and authorizing it in the Tailscale admin console.

### Step 2: Lock Down Access Control Lists (ACLs)
Log into the Tailscale Admin Console, open the **ACL Editor**, and append the following configuration:
```jsonc
{
  "tagOwners": {
    "tag:oob": ["autogroup:admin"]
  },
  "acls": [
    // Permit HTTPS Web console traffic only from authenticated admins
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:oob:443"]
    }
  ],
  "ssh": [
    // Accept-mode SSH for operator -> root avoids interactive check-mode blocking automation
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:oob"],
      "users": ["root"]
    }
  ]
}
```

---

## 3. SRE Verification Check

Validate connection path quality to confirm low-latency stream performance.

### 1. Mesh Node Status Check
Confirm the node is connected to the tailnet:
```bash
tailscale status
```
*Expected Output:*
```
100.110.120.130 oob-kvm              tag:oob             linux   -
```

### 2. Path Direct Connectivity Check
From an operator laptop on the tailnet, ping the KVM node:
```bash
tailscale ping oob-kvm
```
*Expected Output:*
```
pong from oob-kvm (100.110.120.130) via 10.0.20.7:41641 in 2ms (direct)
```
> [!IMPORTANT]
> The ping response must report `(direct)`. If the ping reports `via DERP (relay-name)`, your firewall is blocking UDP port 41641. Direct connections are required to handle 1080p video bandwidth without stutters.

---

## 4. Rollback & Troubleshooting

### Relay Fallback (DERP Connection):
- If `tailscale ping` reports connection through a DERP relay, verify that your site router allows outbound UDP port 41641:
  ```bash
  tailscale netcheck
  ```
  Ensure the output reports `UDP: true`.

### SSH Authentication Hangs:
- If SSH sessions hang with a re-authentication prompt:
  ```
  # Tailscale SSH requires an additional check.
  # To authenticate, visit: https://login.tailscale.com/a/...
  ```
  This is **Tailscale-SSH intercepting the tailnet `:22`** under a check-mode ACL. Two fixes:
  1. **For interactive humans:** set the SSH ACL block to `action: "accept"` (not `"check"`), which
     skips the browser approval.
  2. **For automation (canonical):** do **not** depend on Tailscale-SSH at all. The appliance also runs
     real OpenSSH on `:22`; reach it with an operator key and `BatchMode` so it never prompts:
     ```bash
     ssh -i ~/.ssh/oob_operator_ed25519 -o BatchMode=yes root@oob-kvm
     ```
     The OOB recovery path must work even when the tailnet control plane is degraded or no human is
     present to complete a web flow — so scripts, cron, config-converge, and agent actions use OpenSSH +
     key, never Tailscale-SSH. See [ADR-0008](../../../adr/0008-openssh-over-tailnet-not-tailscale-ssh.md).
     Optional: `tailscale set --ssh=false` on the node makes OpenSSH the only `:22` answerer and removes
     the ambiguity entirely.

### Login Fails with User Error:
- Ensure you log in as **`root`** over SSH. The Unix account on PiKVM is `root`. Logging in as `admin` (the Web UI account) will fail:
  ```bash
  ssh root@oob-kvm
  ```
