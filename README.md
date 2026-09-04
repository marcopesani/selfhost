# Selfhost — GLM-5.3-Flash abliterated on Runpod

Scratchpad and persistent reference for serving **GLM-5.3-Flash (abliterated)** on a dedicated Runpod GPU pod. Constraints, in this order:

1. **Privacy** — requests use an authenticated SSH (or Tailscale) tunnel we opened. A standard Runpod pod is **not** provider-blind; the hard requirement needs confidential computing or hardware we operate.
2. **Context** — SKU menu is **200k or 1M** (ADR-013). **This boot serves 512k** so the usage bar can hit 100% (ADR-025). 8k/64k pools are not a serve target.
3. **Speed** — measure tok/s **in-band**. The LocalMaxxing 1004.9 number is an 8k attractor, not the SLA.

This repo does not deploy anything by itself. It records decisions, frozen benchmark data, serve recipes, and session notes so the next sitting starts from facts, not memory.

## Current state

Read [`STATUS.md`](STATUS.md). Live truth lives there (architecture, next action). Pod id and SSH endpoint stay in `.env`, never in git.

## How to use this directory

| File | Role |
| --- | --- |
| [`STATUS.md`](STATUS.md) | Live truth: what exists, what is blocked, next action |
| [`DECISIONS.md`](DECISIONS.md) | Architecture decisions. Do not silently reverse one |
| [`AGENTS.md`](AGENTS.md) | Instructions for the next agent session |
| [`refs/context.md`](refs/context.md) | 200k vs 1M VRAM, SKUs, in-band numbers |
| [`refs/speed.md`](refs/speed.md) | How to get tok/s (and what 1004 really is) |
| [`refs/abliterated.md`](refs/abliterated.md) | Checkpoint comparison — dealignai CRACK wins |
| [`refs/red-team.md`](refs/red-team.md) | Why Flash UNCENSORED @ 1M is the research model that fits this SKU |
| [`refs/ops.md`](refs/ops.md) | In-pod devops: snapshot + `/ops` skill, not another dashboard |
| [`refs/pricing.md`](refs/pricing.md) | Reseller list $10 / $1 / $20 per MTok (blended premium, ADR-027) |
| [`refs/privacy.md`](refs/privacy.md) | SSH `-L` first, userspace Tailscale overlay, no proxy |
| [`refs/links.md`](refs/links.md) | Source URLs |
| [`refs/snapshots/`](refs/snapshots/) | Frozen LocalMaxxing JSON |
| [`runpod/`](runpod/) | Inventory, cost guard, provision checklist |
| [`configs/`](configs/) | Env, template, serve boot, laptop share pack (`share-laptop.md`) |
| [`scripts/`](scripts/) | Operator scripts (tunnel, measure). Run on the laptop or the pod as marked |
| [`sessions/`](sessions/) | Local sitting notes (gitignored except the template). One file per sitting |
| [`secrets/`](secrets/) | Local-only credentials. Gitignored |

Start a sitting by appending a file under `sessions/` from [`sessions/_template.md`](sessions/_template.md). End it by updating `STATUS.md`.

## Target stack

Two legal configs (ADR-013). Default is **B**.

| Axis | A — 200k / cost | B — 1M / native |
| --- | --- | --- |
| Hardware | 2× RTX PRO 6000 96 GB | 4× RTX PRO 6000 96 GB |
| Window | `--context-length 204800` | `--context-length 1048576` (this boot: **524288**, ADR-025) |
| Engine | SGLang, TileLang DSA, `flashinfer_cutlass` | same |
| Quant | ModelOpt NVFP4 | same |
| Spec at boot | DFLASH2 k=8 | NEXTN/MTP; DFLASH after a completion |
| In-band published | ~150 tok/s analog (EXL3 229k, not our ckpt) | **208 tok/s** MTP (0xSero) |

8k LocalMaxxing 1004.9 tok/s is a **ceiling on a locked-attractor prompt**, not an SLA. See [`refs/context.md`](refs/context.md) and [`refs/speed.md`](refs/speed.md).

Weights we will actually serve are **`dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4`**, not the stock `zai-org/GLM-5.3-Flash` used in the public run. Same architecture; expect a small speed delta, not a different hardware class. For authorized security research on this SKU, that pin stays (ADR-019): CyberGym 84.5% is the **753B** flagship and does not fit 4× 96 GB. The red-team agent is still pi; the specialized package is a **local XPI slice** (`/xp lite`, no webxp) — ADR-021. Writeup: [`refs/red-team.md`](refs/red-team.md).

Fallback if Blackwell / SGLang will not boot on Runpod: official vLLM `glm53-flash` image + `UNCENSORED-FP8` on 4× H200. Documented, slower.

## Privacy invariants

These are not optional. A faster setup that breaks one of them is a failed setup.

- Dedicated **Secure Cloud** pod. Never Community Cloud.
- Never **serverless**. Prompts would transit `api.runpod.ai` and be retained.
- Never expose the **HTTP proxy** (`*.proxy.runpod.net`). It is public and unauthenticated.
- Bind the server to `127.0.0.1`. Reach it only via `ssh -L`. Do not `curl` the Tailscale IP, Serve, SOCKS, or Funnel. Tailnet ACL: laptop → pod :22 only.
- Require a bearer token even on localhost.
- In provider-trusted mode, weights live on an **encrypted volume disk** at `/workspace` (ADR-017). Download once, then `HF_HUB_OFFLINE=1`. Deleting the pod deletes the weights; stop between sittings.
- Disable telemetry (`HF_HUB_DISABLE_TELEMETRY=1`, no request logs).
- Do not put `HF_TOKEN` or `RUNPOD_API_KEY` in the container's public env if the console displays it.
- Runpod’s encrypted volume-disk option is provider-managed and has no BYOK; network volumes cannot use that option. This is cold-storage defense in depth, not protection from a privileged host during inference.
- For provider-blind privacy, require CPU/GPU confidential computing, fresh attestation, and attestation-gated key release for the exact deployment. Do not treat Secure Cloud, SSH, or disk encryption alone as sufficient.

Full threat model: [`refs/privacy.md`](refs/privacy.md).

## Next sitting

Read [`STATUS.md`](STATUS.md). Deploy from the private template `glm-flash-1m` with Encrypt volume ON (config B, ADR-018). Then weights, then the research harness on `/workspace` (ADR-019). Do not swap to 753B on this SKU.
