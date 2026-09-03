# Decisions

Append-only. Newest first. Reverse a decision by adding a new ADR that supersedes the old one.

## ADR-014 — Disk encryption does not make ordinary Runpod provider-blind

**Date:** 2026-09-03
**Status:** accepted
**Qualifies:** ADR-006, ADR-011, and ADR-012

The hard privacy requirement is that Runpod, its host operator, or someone with privileged access to the rented hardware must not be able to read prompts, completions, model weights, or keys.

Runpod’s storage documentation says:

- **Volume disk** can use the console’s encrypted-volume option, but Runpod stores the key, the key cannot be retrieved, and BYOK is unsupported.
- **Container disk and network volumes** cannot use that encrypted-volume feature.
- Runpod’s security controls and host-access policy are valuable isolation and governance controls, not a cryptographic guarantee against a privileged host operator.

Disk or file encryption protects data while it is cold. Inference necessarily puts plaintext and a decryption key into guest memory and GPU memory. An ordinary pod therefore cannot satisfy the hard requirement, even if we encrypt the model before upload or select Runpod’s encrypted volume disk. SSH, Tailscale, loopback binding, and disabled logs protect the request path and reduce accidental retention; they do not protect runtime memory from the host.

**Decision:** do not call an ordinary Runpod Secure Cloud pod private from Runpod. Before provisioning, choose one of:

1. **Provider-trusted mode:** explicitly accept Runpod as trusted for runtime plaintext. If cold-storage defense-in-depth is desired, use an encrypted **volume disk** rather than a network volume, accept Runpod-managed keys, and never put prompts in logs.
2. **Provider-blind mode:** require a documented confidential-computing deployment with a CPU TEE (SEV-SNP or TDX), NVIDIA GPU confidential computing with protected VRAM/PCIe, fresh remote attestation, and customer-controlled or attestation-gated KMS key release.
3. **Own the hardware:** operate the host and storage ourselves.

NVIDIA documents a self-hosted RTX PRO 6000 Blackwell Server Edition validation using AMD SEV-SNP, GPU confidential computing, attestation, and model-key release. That proves the hardware class can participate in such a design, not that Runpod provides the complete service. Until Runpod confirms the exact GPU, data center, VM, attestation, and key-release path, **do not provision a standard pod under the provider-blind requirement**.

## ADR-013 — Serve at 200k or 1M only; pick the SKU to match

**Date:** 2026-09-03
**Status:** accepted
**Supersedes:** the 8k/64k pool in the ADR-004 recipe; 4× as the default SKU when the window is 1M

GLM-5.3-Flash’s native window is **1,048,576**. 8k / 32k / 64k are not serve targets. LocalMaxxing 300–1004 tok/s is ctx=8192 and is not the SLA.

Two legal configs (math in [`refs/context.md`](refs/context.md)):

| | Window | GPUs | KV | Spec at boot |
| --- | --- | --- | --- | --- |
| **A (cost)** | `--context-length 204800` | **2×** RTX PRO 6000 | bf16 | DFLASH2 k=8 |
| **B (native)** | `--context-length 1048576` | **4×** RTX PRO 6000 | bf16 | NEXTN/MTP, then DFLASH |

Do not provision 2× for 1M. Do not provision 4× for a single 200k stream (leftover VRAM is concurrency, not speed). Hopper fallback stays 4× H200 at the same two windows.

Pick A or B **before** `pod create`. Default if unspecified: **B** (native window). 200k on 2× is a tight estimate (~188 GB of 192, before any unmodeled allocator or DFLASH overhead) and has no published NVFP4 boot log.

## ADR-012 — API only via `ssh -L`; ACL :22; no Serve / SOCKS / Funnel

**Date:** 2026-09-02
**Status:** accepted
**Supersedes:** ADR-011 rank-3 Serve; the SOCKS line in the old boot snippet

Userspace Tailscale rewrites inbound `<tailscale-ip>:<port>` to `127.0.0.1:<port>`. A default `*:*` ACL therefore publishes SGLang to the tailnet with no Serve and no SOCKS. Close that with an ACL: laptop (or `autogroup:self`) → pod **:22 only**. Reach the API with **Tailscale SSH + `ssh -L`**. Do not start `--socks5-server`, `tailscale serve`, or Funnel. Do not make the pod an exit node.

First sitting: browser `tailscale up` (user device). Keep public TCP 22 as bootstrap and break-glass; day-to-day do not point clients at the public IP. `ssh.runpod.io` cannot local-forward.

## ADR-011 — SSH localhost-forward is rank 1; Tailscale is the overlay

**Date:** 2026-09-02
**Status:** accepted; Serve convenience superseded by ADR-012
**Supersedes:** ADR-009 (partial — kernel VPN still impossible)

Fewest third parties on first sitting: Secure Cloud, Jupyter off, no HTTP ports, bind `127.0.0.1`, API key, **direct TCP 22 + `ssh -L`**. After userspace Tailscale is up, day-to-day is Tailscale SSH + `-L` (ADR-012). Do not use Basic SSH via `ssh.runpod.io` as the daily path. Funnel / Cloudflare Tunnel / proxy still forbidden. Serve and SOCKS are now also forbidden (ADR-012).

## ADR-010 — Pin `UNCENSORED-NVFP4`; rbinrs is stale

**Date:** 2026-09-02
**Status:** accepted
**Supersedes:** ADR-005 mirror list

Primary id is **`dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4`** (2026-08-29 loop-fix, 2026-09-02 reupload). The ABLITERATED twin is advertised as the same CRACK but commits diverge — do not mix. **`rbinrs/…-ABLITERATED-NVFP4` is a pre-fix snapshot — do not download.** Draft `incoai/GLM-5.3-Flash-DFlash2` is CC BY-NC-ND; pin `7d74cdd`. Serve NVFP4 on **SGLang**, not vLLM-on-SM120 (U+FFFD, vllm#54150).

## ADR-009 — Userspace Tailscale is the private door; kernel VPN is impossible

**Date:** 2026-09-02
**Status:** superseded in part by ADR-011

Runpod will not map `/dev/net/tun` or `NET_ADMIN`. Kernel Tailscale/WireGuard is out. Userspace `tailscaled --tun=userspace-networking` still works. ADR-011 ranks **direct TCP 22 + `ssh -L`** first (fewer third parties) and Tailscale as the overlay. HTTP proxy, serverless, Funnel, and Cloudflare Tunnel remain forbidden. Details: [`refs/privacy.md`](refs/privacy.md).

## ADR-008 — Primary checkpoint is dealignai CRACK NVFP4, not orcarouter

**Date:** 2026-09-02
**Status:** accepted

orcarouter is more popular and better documented as a method paper. Their own benches still show 11–18% harmful refusal at low effort, and their NVFP4 drops MTP. dealignai reports HarmBench-320 at 0% on off/max, keeps a cracked MTP head, and is ungated. That matches both the uncensor goal and the SGLang+DFLASH2 speed track. orcarouter is a research alternate, not the served artifact. Details: [`refs/abliterated.md`](refs/abliterated.md).

## ADR-007 — 1004.9 tok/s is a ceiling, not the SLA

**Date:** 2026-09-02
**Status:** accepted

The LocalMaxxing run we are chasing (`cmtk0maew03mrp701oyaivvka`) is the fastest approved GLM-5.3-Flash result on that site. Its notes describe a locked attractor, n-gram proposals that skip the draft forward, clock locks, and best-of-6. We copy the **hardware + engine + flags**. We do not treat the headline number as the definition of done.

Done for speed = we can serve the abliterated model over the private tunnel and we have our own measured tok/s, TTFT, and VRAM on a real prompt.

## ADR-006 — Weights on a High-Performance network volume

**Date:** 2026-09-02
**Status:** accepted

FP8 ≈ 306 GiB, NVFP4 ≈ 180–230 GiB, plus the DFlash2 draft. Re-downloading from Hugging Face on every boot is slow, billable, and a privacy leak (HF sees the pull). The volume is created first, in the DC that has the GPUs, High-Performance tier (immutable after create). Pod `/workspace` is that volume.

We do **not** use Runpod host-side HF model cache. That feature is aimed at serverless and still involves Runpod's cache plane.

## ADR-005 — Abliterated NVFP4 is the primary checkpoint

**Date:** 2026-09-02
**Status:** superseded by ADR-010

Primary weights were listed as `dealignai/GLM-5.3-Flash-ABLITERATED-NVFP4` with rbinrs as a live mirror. ADR-010 pins **UNCENSORED-NVFP4** and marks rbinrs stale.

Draft (unchanged): `incoai/GLM-5.3-Flash-DFlash2`.

Fallback weights if NVFP4 will not load: `dealignai/GLM-5.3-Flash-UNCENSORED-FP8`.

We do not serve stock `zai-org/GLM-5.3-Flash` as the primary model. The public benchmark used stock weights; we accept that as the speed reference, not the served artifact.

CRACK notes: fully uncensored at reasoning off / max. Low effort is intentionally more conservative. Default `reasoning_effort` to `max`.

## ADR-004 — Speed track is SGLang + NVFP4 + DFLASH2 on 2× RTX PRO 6000 Blackwell

**Date:** 2026-09-02
**Status:** accepted

This is the only stack that has published 800–1004 tok/s on LocalMaxxing for this model. vLLM on the same 2× card sits in the 150–190 tok/s band. Official vLLM FP8 recipes target Hopper TP=4/8 and report ~163 tok/s single-stream (211 with MTP) on H200.

Fallback track (if Runpod has no Secure Cloud 2× RTX PRO 6000, or SGLang/SM120 will not boot): `vllm/vllm-openai:glm53-flash` + abliterated FP8 on 4× H200 (`HOPPER_141`).

Do not start on 8× 3090 or consumer cards. The model does not belong there for this project's speed goal.

## ADR-003 — SSH (or Tailscale) only. No HTTP proxy, no public TCP for the API

**Date:** 2026-09-02
**Status:** accepted

Runpod's HTTP proxy is public, unauthenticated, Cloudflare-fronted, and times out at 100s. That is incompatible with the privacy goal and with long generations.

The inference process binds `127.0.0.1:8000`. The laptop reaches it with:

```bash
ssh -N -L 8000:127.0.0.1:8000 <pod>
```

Tailscale/headscale is an allowed later upgrade (still no proxy ports). A bearer token is required even on the tunnel.

SSH itself uses Runpod TCP port 22. That is accepted: it carries encrypted traffic we initiate, not an open model API.

## ADR-002 — Dedicated Secure Cloud pod, never serverless, never Community Cloud

**Date:** 2026-09-02
**Status:** accepted

- **Pod** so the process stays up, we control the listen address, and we can SSH.
- **Secure Cloud** (T3/T4 DCs) for dedicated hardware and stable IPs. Community Cloud is cheaper and shared; rejected.
- **Not serverless:** every prompt would go through `api.runpod.ai`, be queued, and be retained for minutes. FlashBoot/host cache also spread weights onto Runpod-managed hosts we do not control.

Idle cost is the trade. Stop the pod when a sitting ends unless the user asks to keep it warm. The volume keeps the weights.

## ADR-001 — This repo is the operator scratchpad

**Date:** 2026-09-02
**Status:** accepted

Empty workspace, no app to ship. The directory exists so hardware choices, serve flags, measurements, and live resource IDs survive across chats. Prefer updating markdown + JSON snapshots over building automation until a recipe has been measured once.
