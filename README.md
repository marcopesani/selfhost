# Selfhost — GLM-5.3-Flash abliterated on Runpod

Scratchpad and persistent reference for serving **GLM-5.3-Flash (abliterated)** on a dedicated Runpod GPU pod. Two constraints, in this order:

1. **Privacy** — prompts, completions, and weights never leave a machine we control, except over an authenticated SSH (or Tailscale) tunnel we opened.
2. **Speed** — chase the LocalMaxxing ceiling of **1004.9 tok/s** on the same stack that produced it.

This repo does not deploy anything by itself. It records decisions, frozen benchmark data, serve recipes, and session notes so the next sitting starts from facts, not memory.

## Current state

Read [`STATUS.md`](STATUS.md). There is no live pod yet.

## How to use this directory

| File | Role |
| --- | --- |
| [`STATUS.md`](STATUS.md) | Live truth: what exists, what is blocked, next action |
| [`DECISIONS.md`](DECISIONS.md) | Architecture decisions. Do not silently reverse one |
| [`AGENTS.md`](AGENTS.md) | Instructions for the next agent session |
| [`refs/speed.md`](refs/speed.md) | How to get tok/s (and what 1004 really is) |
| [`refs/abliterated.md`](refs/abliterated.md) | Checkpoint comparison — dealignai CRACK wins |
| [`refs/privacy.md`](refs/privacy.md) | SSH `-L` first, userspace Tailscale overlay, no proxy |
| [`refs/links.md`](refs/links.md) | Source URLs |
| [`refs/snapshots/`](refs/snapshots/) | Frozen LocalMaxxing JSON |
| [`runpod/`](runpod/) | Inventory, cost guard, provision checklist |
| [`configs/`](configs/) | Env + serve command templates |
| [`scripts/`](scripts/) | Operator scripts (tunnel, measure). Run on the laptop or the pod as marked |
| [`sessions/`](sessions/) | Dated notes. One file per sitting |
| [`secrets/`](secrets/) | Local-only credentials. Gitignored |

Start a sitting by appending a file under `sessions/` from [`sessions/_template.md`](sessions/_template.md). End it by updating `STATUS.md`.

## Target stack (speed track)

Replicate [LocalMaxxing run `cmtk0maew03mrp701oyaivvka`](https://www.localmaxxing.com/en/models/zai-org/GLM-5.3-Flash?run=cmtk0maew03mrp701oyaivvka):

| Axis | Value |
| --- | --- |
| Hardware | 2× RTX PRO 6000 Blackwell 96 GB (TP=2) |
| Engine | SGLang |
| Quant | ModelOpt NVFP4 |
| Spec decode | DFLASH2, draft `incoai/GLM-5.3-Flash-DFlash2` @ `7d74cdd`, **start at 8 draft tokens** |
| Attention | DSA / TileLang |
| MoE runner | `flashinfer_cutlass` |
| Reported | **1004.89 tok/s out**, 4460 tok/s prefill, 125 ms TTFT, 187.9 GB VRAM |

That number is a **ceiling on a locked-attractor prompt**, not an SLA. See [`refs/benchmark.md`](refs/benchmark.md).

Weights we will actually serve are **`dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4`**, not the stock `zai-org/GLM-5.3-Flash` used in the public run. Same architecture; expect a small speed delta, not a different hardware class.

Fallback if Blackwell / SGLang will not boot on Runpod: official vLLM `glm53-flash` image + `UNCENSORED-FP8` on 4× H200. Documented, slower.

## Privacy invariants

These are not optional. A faster setup that breaks one of them is a failed setup.

- Dedicated **Secure Cloud** pod. Never Community Cloud.
- Never **serverless**. Prompts would transit `api.runpod.ai` and be retained.
- Never expose the **HTTP proxy** (`*.proxy.runpod.net`). It is public and unauthenticated.
- Bind the server to `127.0.0.1`. Reach it only via `ssh -L`. Do not `curl` the Tailscale IP, Serve, SOCKS, or Funnel. Tailnet ACL: laptop → pod :22 only.
- Require a bearer token even on localhost.
- Weights live on a **network volume** in the same DC. Download once. Do not re-pull from Hugging Face on every boot.
- Disable telemetry (`HF_HUB_DISABLE_TELEMETRY=1`, no request logs).
- Do not put `HF_TOKEN` or `RUNPOD_API_KEY` in the container's public env if the console displays it.

Full threat model: [`refs/privacy.md`](refs/privacy.md).

## Next sitting

1. Confirm Runpod auth (`runpodctl user`) and GPU stock for 2× RTX PRO 6000 Blackwell on Secure Cloud.
2. Create a High-Performance network volume in the DC that has that GPU.
3. Do **not** expose HTTP ports. Jupyter off. SSH only.
4. Pull `dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4` + DFlash2 (`7d74cdd`) onto the volume.
5. Boot SGLang bound to `127.0.0.1`, tunnel with `ssh -L`, measure a real prompt (DFLASH k=8).
