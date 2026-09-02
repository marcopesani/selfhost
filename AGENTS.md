# Agent instructions

This directory is a **scratchpad**, not a product repo. Your job in a new session is to continue the self-host of GLM-5.3-Flash abliterated on Runpod without losing privacy or the speed target.

## First 60 seconds

1. Read [`STATUS.md`](STATUS.md). That is the live truth.
2. Read [`DECISIONS.md`](DECISIONS.md). Do not reverse an ADR without writing a new one.
3. If the user mentions a past sitting, read the latest file in [`sessions/`](sessions/).
4. Check [`runpod/inventory.md`](runpod/inventory.md) before creating any billable resource.
5. Speed / checkpoint / privacy answers are already in `refs/speed.md`, `refs/abliterated.md`, `refs/privacy.md`. Do not re-litigate them without new measurements.

## Hard rules

- Do not create a Community Cloud pod.
- Do not create a serverless endpoint for this model. Prompts would leave the pod through Runpod's invoke API.
- Do not add HTTP ports to the pod. Do not hand the user a `*.proxy.runpod.net` URL.
- Do not bind vLLM/SGLang to `0.0.0.0`. Userspace Tailscale already rewrites tailnet ports onto localhost — close that with ACL :22, not by advertising the API.
- Do not commit `.env`, `secrets/`, API keys, SSH keys, or model weights.
- Do not skip the cost guard. A 2× RTX PRO 6000 pod bills by the second while running. Set `--terminate-after` on experimental pods; stop or delete when a sitting ends unless the user says keep it warm.
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
pick DC with 2× RTX PRO 6000 Blackwell Secure Cloud stock
→ create High-Performance network volume there
→ create pod attached to that volume, SSH only, no HTTP ports
→ download weights once onto the volume
→ start SGLang on 127.0.0.1
→ SSH tunnel from the laptop
→ measure
```

Use `runpodctl` (or Runpod MCP if connected). Prefer `runpodctl pod create --wait`. Check live `--help`; do not invent flags.

## Speed vs honesty

The LocalMaxxing headline (1004.9 tok/s) used a **locked attractor** and n-gram proposals that skipped the draft forward. Reproduce the **command and hardware**, then report our own numbers. Do not claim we matched 1004 tok/s unless we ran the same protocol and got it.

Realistic bands to expect:

| Band | What it means |
| --- | --- |
| ~150–190 tok/s | vLLM floor on 2× RTX PRO 6000 if SGLang will not boot |
| ~160–210 tok/s | dealignai FP8 + MTP on 4× H200, single stream |
| **~300–391 tok/s** | DFLASH2 k=8, real prompts, their own steady-state |
| ~443–514 tok/s | same stack, **best-of-N** — do not report as SLA |
| ~800–1004 tok/s | only if DFLASH2 + n-gram attractor reproduces |

## Privacy review before any "it is up" message

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

## Out of scope unless the user asks

Publishing a site, opening a PR, committing, building a UI, or serving the stock (non-abliterated) checkpoint as the primary model.
