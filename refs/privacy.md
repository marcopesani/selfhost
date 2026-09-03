# Privacy — Runpod without leaking prompts

Researched 2026-09-02; encryption follow-up 2026-09-03. Official Runpod, NVIDIA, Tailscale, GitHub, and Discord sources. Sources in [`links.md`](links.md).

## New requirement: provider-blind confidentiality

Short answer: **ordinary Runpod cannot provide this guarantee**. Runpod documents an optional encrypted **volume disk**, but Runpod stores the key, the key cannot be retrieved, and bring-your-own-key (BYOK) is unsupported. The same storage page says the encrypted-volume feature does not apply to container disks or network volumes. Runpod’s security controls and host-access policy are useful defense in depth, but they do not cryptographically exclude a privileged host operator.

Disk encryption protects cold storage: a powered-off disk, a stolen disk, or a storage snapshot without its key. It does not protect a live inference process. To load the model and answer a prompt, the pod must hold plaintext weights, prompt tokens, activations, and a decryption key in guest memory and GPU memory. Encrypting files before upload or adding LUKS/FUSE-style encryption only moves the plaintext boundary to startup/runtime; it does not hide it from a host with memory or GPU-debug access.

There are two honest modes:

- **Provider-trusted:** keep the current SSH/Tailscale and no-logging controls; optionally use Runpod’s encrypted volume disk for cold-storage defense in depth; explicitly accept that Runpod/the hardware operator could inspect runtime plaintext. Do not use a network volume if the requirement is specifically Runpod’s customer-visible volume encryption option.
- **Provider-blind:** require a confidential VM with CPU TEE (AMD SEV-SNP or Intel TDX), NVIDIA GPU confidential computing with protected VRAM/PCIe, fresh remote attestation, and key release gated on the attestation result. NVIDIA’s self-hosted reference validates this shape on RTX PRO 6000 Blackwell Server Edition, but that is not evidence that Runpod offers it.

No current public Runpod documentation in the indexed docs set describes a complete confidential-VM/GPU, attestation, and customer-key-release product. Treat that as **unverified**, not as support. Ask Runpod to confirm the exact GPU SKU, data center, CPU TEE, GPU CC mode, attestation evidence, and KMS/key-release path before provisioning. Until then, the provider-blind requirement puts the standard Runpod plan on hold.

## Threat model

| Actor | What they can see if we are sloppy | What we can deny them |
| --- | --- | --- |
| **Runpod operator / DC staff** | Host RAM, GPU VRAM, disk, console env, container logs they collect | In provider-trusted mode: only network exposure and accidental retention. Provider-blind mode requires confidential computing; ordinary pod controls do not deny runtime plaintext |
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
| Container disk | Runpod’s broad platform claim; no customer key | Ephemeral; the storage docs say the encrypted-volume feature does not apply |
| Volume disk | Optional **Encrypt volume**; **Runpod holds the key, no BYOK** | Retained for the Pod lease; key is passed to the container at runtime |
| **Network volume** | Cannot use Runpod’s encrypted-volume feature; no customer key | Persistent and needed for 180–300 GiB weights, but leaves the storage plane provider-trusted |
| User-encrypted artifact | Yes, if the key stays off-pod while stopped | The key and plaintext still enter pod/GPU memory during inference |
| HF cache after first pull | same as the volume | Set `HF_HUB_OFFLINE=1`, `HF_HUB_DISABLE_TELEMETRY=1` |

Runpod’s separate security guide says that all platform data is encrypted at rest by default, while the storage page narrowly says container disks and network volumes cannot use the encrypted-volume feature. These can describe different provider-managed layers, but neither statement gives us BYOK or runtime confidentiality. We therefore use the storage page for the storage choice and retain Runpod as a trusted party unless a confidential-computing path is verified.

Do not put `HF_TOKEN` / `RUNPOD_API_KEY` in template env (console displays it). Use a file on the volume, mode 600.

Disable request logs in vLLM/SGLang. Do not submit prompts to LocalMaxxing from this pod.

## Runpod platform facts (sourced)

- Secure Cloud: T3/T4, vetted partners, SOC 2 / ISO 27001 / PCI DSS cited. [docs](https://docs.runpod.io/references/security-and-compliance)
- Community: peer hosts; ToS forbids inspection; physically they can. Rejected.
- Multi-tenant isolation is **containers**, even on Secure Cloud. "Dedicated GPU" ≠ dedicated hypervisor.
- Storage page: volume-disk encryption is Runpod-keyed and has no BYOK; container disk and network volumes cannot use that feature. [storage docs](https://docs.runpod.io/pods/storage/types#encrypted-volumes)
- No public Runpod docs found in the current indexed set for a complete confidential VM/GPU + attestation + customer-key-release path. This remains a support/sales verification item, not proof of absence.
- HTTP proxy path: User → Cloudflare → Runpod LB → pod. Public, HTTPS, **100 s**. [docs](https://docs.runpod.io/pods/configuration/expose-ports)
- GDPR: they claim it for EU DCs. Pin an EU DC if residency matters; we have not decided.
- Global networking: pod-to-pod only, ~100 Mbps, not a laptop path.

## Checklist before calling it private

- [ ] Privacy mode is explicit: **provider-trusted** or **provider-blind**
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
- [ ] Provider-trusted mode only: if at-rest encryption is required, use an encrypted volume disk, accept Runpod-managed keys, and do not call this provider-blind
- [ ] Provider-blind mode only: verify CPU TEE, GPU CC, fresh attestation, and attestation-gated KMS key release for the exact SKU/DC before uploading data
- [ ] `swapon --show` is empty or otherwise verified not to receive prompts
- [ ] In provider-trusted mode, explicitly accept residual: Runpod can still inspect runtime plaintext or dump the GPU
