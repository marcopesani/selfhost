# Agent instructions

This directory is a **scratchpad**, not a product repo. Your job in a new session is to continue the self-host of GLM-5.3-Flash abliterated on Runpod without losing privacy or the speed target. Context is **200k or 1M only** (ADR-013).

## First 60 seconds

1. Read [`STATUS.md`](STATUS.md). That is the live truth.
2. Read [`DECISIONS.md`](DECISIONS.md). Do not reverse an ADR without writing a new one.
3. If the user mentions a past sitting, read the latest file in [`sessions/`](sessions/).
4. Check [`runpod/inventory.md`](runpod/inventory.md) before creating any billable resource.
5. Speed / checkpoint / privacy / context answers are already in `refs/speed.md`, `refs/abliterated.md`, `refs/privacy.md`, `refs/context.md`. Do not re-litigate them without new measurements. Do not revive an 8k/64k pool.

## Hard rules

- Do not create a Community Cloud pod.
- Do not create a serverless endpoint for this model. Prompts would leave the pod through Runpod's invoke API.
- Do not add HTTP ports to the pod. Do not hand the user a `*.proxy.runpod.net` URL.
- Do not bind vLLM/SGLang to `0.0.0.0`. Userspace Tailscale already rewrites tailnet ports onto localhost — close that with ACL :22, not by advertising the API.
- Do not commit `.env`, `secrets/`, API keys, SSH keys, or model weights.
- Do not call ordinary Runpod provider-blind. Its optional volume-disk encryption is Runpod-keyed, has no BYOK, and does not protect plaintext in guest/GPU memory. If provider-blind privacy is required, do not provision until CPU/GPU confidential computing, attestation, and gated key release are verified.
- Do not skip the cost guard. A 2× or 4× RTX PRO 6000 pod bills by the second while running. Set `--terminate-after` on experimental pods; stop or delete when a sitting ends unless the user says keep it warm. Do not buy 4× for one 200k stream.
- Do not treat "Running" in the console as success. Success is a completion returned over the SSH tunnel.

## What to write down

Every sitting that changes state must:

1. Create or update `sessions/YYYY-MM-DD-<slug>.md` from [`sessions/_template.md`](sessions/_template.md).
2. Update `STATUS.md` (what exists, what failed, next action).
3. If a resource was created or destroyed, update `runpod/inventory.md`.
4. If an architecture choice changed, add an ADR in `DECISIONS.md`.
5. If a measurement was taken, append a row to `refs/benchmark.md` (our runs section) and drop the raw JSON in `logs/`.

## Provision order

Volume first, then compute in that same data center. Never the reverse.

```
verify provider-blind support or explicitly record provider-trusted mode
→ pick A (2× / 200k) or B (4× / 1M; default)
→ pick DC with that SKU on Secure Cloud
→ create High-Performance network volume there
→ create pod attached to that volume, SSH only, no HTTP ports
→ download weights once onto the volume
→ start SGLang on 127.0.0.1 at 204800 or 1048576
→ SSH tunnel from the laptop
→ measure a prompt in-band, not 403 tokens @ 8k
```

Use `runpodctl` (or Runpod MCP if connected). Prefer `runpodctl pod create --wait`. Check live `--help`; do not invent flags.

## Speed vs honesty

The LocalMaxxing headline (1004.9 tok/s) used a **locked attractor** and n-gram proposals that skipped the draft forward. Reproduce the **command and hardware**, then report our own numbers. Do not claim we matched 1004 tok/s unless we ran the same protocol and got it.

Realistic bands to expect:

| Band | Window | What it means |
| --- | --- | --- |
| ~140–154 tok/s | 229k–353k | 2× EXL3 analog (not our NVFP4). Honest 2× long-ctx floor |
| **208 tok/s** | 1M configured | 4× NVFP4 NEXTN MTP5 (0xSero). In-band published |
| ~160–210 tok/s | unspecified | dealignai FP8 + MTP on 4× H200, short-prompt |
| **~300–391 tok/s** | **8k — out of band** | DFLASH2 k=8 steady-state. Do not quote as 200k/1M |
| ~443–514 tok/s | 8k | same stack, **best-of-N** — do not report as SLA |
| ~800–1004 tok/s | 8k | only if DFLASH2 + n-gram attractor reproduces |

## Privacy review before any "it is up" message

- [ ] Privacy mode is explicit: provider-trusted or provider-blind
- [ ] Secure Cloud
- [ ] Jupyter off
- [ ] No HTTP ports / no proxy URL
- [ ] Process listening on `127.0.0.1` only
- [ ] Bearer token required
- [ ] Telemetry off
- [ ] Weights on the volume, not re-downloaded
- [ ] Tailnet ACL :22 only (userspace otherwise publishes localhost)
- [ ] No SOCKS / Serve / Funnel / exit node
- [ ] Sample request via `ssh -L` to `127.0.0.1`, not `http://100.x:8000`, not the proxy
- [ ] Provider-trusted only: encrypted volume disk if cold-storage encryption is required; accept Runpod-managed key and runtime access
- [ ] Provider-blind only: exact CPU TEE, GPU CC, fresh attestation, and attestation-gated KMS key release verified
- [ ] `swapon --show` is empty or otherwise verified not to receive prompts

## Out of scope unless the user asks

Publishing a site, opening a PR, committing, building a UI, or serving the stock (non-abliterated) checkpoint as the primary model.
