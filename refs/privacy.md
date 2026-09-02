# Privacy — Runpod without leaking prompts

Researched 2026-09-02. Official Runpod + Tailscale docs, GitHub, Discord archive. Sources in [`links.md`](links.md).

## Threat model

| Actor | What they can see if we are sloppy | What we can deny them |
| --- | --- | --- |
| **Runpod operator / DC staff** | Host RAM, GPU VRAM, disk, console env, container logs they collect | Prompt contents *in transit over the public internet*; Community-Cloud peer hosts (by not using Community) |
| **Other Runpod tenants** | Nothing, if Secure Cloud + container isolation holds | Cross-tenant disk/GPU. Do not share a Community host. |
| **Cloudflare + Runpod HTTP proxy** | Full HTTP request/response if we use `*.proxy.runpod.net` | Everything — **do not use the proxy** |
| **Runpod serverless invoke** | Prompts retained minutes on `api.runpod.ai` | Everything — **do not use serverless** |
| **Hugging Face** | Which repo we pull, when, from which IP | After the first pull: serve from the volume, `HF_HUB_OFFLINE=1` |
| **Tailscale coordination** | Node IPs, keys, who is online. Not WireGuard payload | Prompt bytes (encrypted node-to-node) |
| **Tailnet peers (default ACL)** | Any localhost TCP via userspace netstack, including `:8000` | ACL laptop → pod :22 only |
| **The public internet** | Anything we bind on a public TCP/HTTP port | Bind `127.0.0.1`, no HTTP ports, SSH key-only |
| **Our laptop** | Local tunnel, shell history, `.env` | Disk encryption / don't log prompts |

Honest residual: **anyone with hypervisor/GPU-debug on the Secure Cloud host can dump VRAM.** Runpod's ToS and SOC 2 say they will not. That is a policy control, not a cryptographic one. If that residual is unacceptable, do not use a rented GPU.

## Ranked access designs

| Rank | Design | Residual | Use |
| ---: | --- | --- | --- |
| 1 | Secure Cloud, **no HTTP ports**, Jupyter **off**, SGLang on `127.0.0.1` + API key, **TCP 22 + `ssh -L`** (direct, not `ssh.runpod.io`) | Runpod host/VRAM/logs. Public SSH listener (ciphertext) | **First sitting / fewest third parties** |
| 2 | (1) + **userspace Tailscale** + **ACL :22 only** + Tailscale SSH + `ssh -L` | Tailscale coord sees node metadata, not payload | **Day-to-day** after overlay is up. TCP 22 stays break-glass |
| — | `curl http://100.x:8000` / default `*:*` ACL | Userspace netstack rewrites tailnet ports onto localhost | **Hazard — close with ACL** |
| — | `tailscale serve` / `--socks5-server` | Advertises localhost (and SOCKS :1055) on the tailnet | **Forbidden** |
| — | HTTP proxy | Public, unauth, Cloudflare sees all, 100 s cap | **Forbidden** |
| — | Serverless / FlashBoot | Prompts on Runpod API | **Forbidden** |
| — | `tailscale funnel` / Cloudflare Tunnel | Third party terminates TLS and sees traffic | **Forbidden** |
| — | Community Cloud | Peer host can inspect | **Forbidden** |
| — | Kernel WireGuard / Tailscale TUN | Runpod does not give `/dev/net/tun` or `NET_ADMIN` ([runpodctl#272](https://github.com/runpod/runpodctl/issues/272)) | **Impossible** |

## Why Tailscale, and why userspace

Kernel Tailscale needs `/dev/net/tun`. Runpod pods are unprivileged. Discord (2024) and runpodctl#272 confirm this is still a platform gap, not a CLI gap.

**Userspace networking works** (`tailscaled --tun=userspace-networking`):

- No TUN device. Laptop stays on **kernel** Tailscale. Only the pod is userspace. Never `--advertise-exit-node`.
- `tailscaled` speaks WireGuard in userspace.
- **Inbound `<tailscale-ip>:<port>` is rewritten to `127.0.0.1:<port>`** ([KB 1112](https://tailscale.com/kb/1112/userspace-networking), [tailscale#10267](https://github.com/tailscale/tailscale/issues/10267)). A default `*:*` ACL therefore publishes **every localhost TCP port**, including SGLang, with no Serve and no SOCKS.
- **Close that with ACL:** laptop / `autogroup:self` → pod **:22 only**. Then netstack would still *try* `:8000`, but the packet filter drops it.
- **Reach the API with Tailscale SSH + `ssh -L`.** Tailscale SSH intercepts :22 on the Tailscale IP only; OpenSSH on `0.0.0.0:22` still serves Runpod’s public mapping. `-L` needs `AllowLocalPortForwarding`.
- Do **not** start `--socks5-server` (outbound-only, and netstack would publish `:1055`). Do **not** `tailscale serve` or Funnel.

First sitting: TCP 22 + `ssh -L`, then browser `tailscale up` so the pod is a **user device**. Tagged authkeys skip `autogroup:self` until SSH rules are written. After overlay is up, day-to-day is Tailscale SSH + `-L`. Keep public TCP 22 as break-glass; do not point clients at the public IP.

Official templates start **Jupyter on by default** — uncheck it. `ssh.runpod.io` / web terminal is a Runpod gateway: **no `-L` / scp**. Use it only to start Tailscale. Put keys in Runpod Secrets, not visible env. `--log-requests` stays off (`SGLANG_DISABLE_REQUEST_LOGGING=true`).

Community recipe: [koshimazaki/tailscale-runpod](https://github.com/koshimazaki/tailscale-runpod). Persist **`--statedir=/workspace/tailscale`** so a pod stop does not mint a new node.

## Recommended architecture

```
Laptop (kernel Tailscale)
  client → http://127.0.0.1:8000 + Bearer
      │
      │ ssh -N -L 8000:127.0.0.1:8000 root@glm-flash
      │ (OpenSSH → Tailscale SSH on the pod)
      ▼
  WireGuard to pod (direct if possible; DERP if not)
      │
      ├─ day-to-day admin: same Tailscale SSH session
      └─ break-glass only: Runpod public TCP 22 → OpenSSH

Runpod Secure Cloud
  HTTP ports: none. TCP 22 only (OpenSSH, key-only). Jupyter off.
  tailscaled --tun=userspace-networking --statedir=/workspace/tailscale --ssh
  ACL: laptop → pod :22 only
  SGLang: 127.0.0.1:8000 + bearer, telemetry off
```

Keep public TCP 22. Do not go Tailscale-SSH-only on the first sitting. Dropping it later is a hardening step whose only recovery is the web terminal (visible to Runpod).

## Pod boot snippet

Canonical script: [`configs/tailscale-userspace.sh`](../configs/tailscale-userspace.sh). Run once over web SSH / TCP 22. Persist on the network volume. First `tailscale up` prints a login URL — click it so the pod is a user device.

Laptop (after `tailscale status` shows `glm-flash` active):

```bash
ssh -N -L 8000:127.0.0.1:8000 root@glm-flash
# or: tailscale ssh -N -L 8000:127.0.0.1:8000 root@glm-flash
curl -H "Authorization: Bearer $GLM_API_KEY" http://127.0.0.1:8000/v1/models
```

If `-L` is denied, the Tailscale SSH rule needs local port forwarding. Fallback is OpenSSH `-L` over Runpod TCP 22.

## Storage and telemetry

| Store | Encrypted at rest? | Notes |
| --- | --- | --- |
| Container disk | Runpod AES-256 (their key) | Wiped on stop |
| Volume disk | Optional extra encrypt; **Runpod holds the key, no BYOK** | Dies with the pod |
| **Network volume** | **Cannot be customer-encrypted** | Needed for 180–300 GiB weights. Residual: Runpod storage plane |
| HF cache after first pull | same as the volume | Set `HF_HUB_OFFLINE=1`, `HF_HUB_DISABLE_TELEMETRY=1` |

Do not put `HF_TOKEN` / `RUNPOD_API_KEY` in template env (console displays it). Use a file on the volume, mode 600.

Disable request logs in vLLM/SGLang. Do not submit prompts to LocalMaxxing from this pod.

## Runpod platform facts (sourced)

- Secure Cloud: T3/T4, vetted partners, SOC 2 / ISO 27001 / PCI DSS cited. [docs](https://docs.runpod.io/references/security-and-compliance)
- Community: peer hosts; ToS forbids inspection; physically they can. Rejected.
- Multi-tenant isolation is **containers**, even on Secure Cloud. "Dedicated GPU" ≠ dedicated hypervisor.
- HTTP proxy path: User → Cloudflare → Runpod LB → pod. Public, HTTPS, **100 s**. [docs](https://docs.runpod.io/pods/configuration/expose-ports)
- GDPR: they claim it for EU DCs. Pin an EU DC if residency matters; we have not decided.
- Global networking: pod-to-pod only, ~100 Mbps, not a laptop path.

## Checklist before calling it private

- [ ] `cloudType=SECURE`
- [ ] Jupyter off
- [ ] Zero HTTP ports on the template
- [ ] Process listen address is `127.0.0.1`
- [ ] Bearer token required
- [ ] Tailscale userspace up, `--statedir` on `/workspace`, **no SOCKS / Serve / Funnel / exit node**
- [ ] Tailnet ACL: this laptop → pod **:22 only** (default `*:*` publishes localhost)
- [ ] Sample request via `ssh -L` to `127.0.0.1:8000`, not `http://100.x:8000`, not the proxy
- [ ] `HF_HUB_OFFLINE=1` after the first pull
- [ ] No prompt logging
- [ ] Accept residual: Runpod can still dump the GPU
