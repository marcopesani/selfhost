# Selfhost — GLM-5.3-Flash abliterated on Runpod

Scratchpad and persistent reference for serving **GLM-5.3-Flash (abliterated)** on a dedicated Runpod GPU pod. Constraints, in this order:

1. **Privacy** — requests use an authenticated SSH (or Tailscale) tunnel we opened. A standard Runpod pod is **not** provider-blind; the hard requirement needs confidential computing or hardware we operate.
2. **Context** — **200k or 1M only.** The model is native 1,048,576; 8k/64k pools are not a serve target (ADR-013).
3. **Speed** — measure tok/s **in-band**. The LocalMaxxing 1004.9 number is an 8k attractor, not the SLA.

This repo does not deploy anything by itself. It records decisions, frozen benchmark data, serve recipes, and session notes so the next sitting starts from facts, not memory.

## Current state

Read [`STATUS.md`](STATUS.md). There is no live pod yet.

## How to use this directory

| File | Role |
| --- | --- |
| [`STATUS.md`](STATUS.md) | Live truth: what exists, what is blocked, next action |
| [`DECISIONS.md`](DECISIONS.md) | Architecture decisions. Do not silently reverse one |
| [`AGENTS.md`](AGENTS.md) | Instructions for the next agent session |
| [`refs/context.md`](refs/context.md) | 200k vs 1M VRAM, SKUs, in-band numbers |
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

## Target stack

Two legal configs (ADR-013). Default is **B**.

| Axis | A — 200k / cost | B — 1M / native |
| --- | --- | --- |
| Hardware | 2× RTX PRO 6000 96 GB | 4× RTX PRO 6000 96 GB |
| Window | `--context-length 204800` | `--context-length 1048576` |
| Engine | SGLang, TileLang DSA, `flashinfer_cutlass` | same |
| Quant | ModelOpt NVFP4 | same |
| Spec at boot | DFLASH2 k=8 | NEXTN/MTP; DFLASH after a completion |
| In-band published | ~150 tok/s analog (EXL3 229k, not our ckpt) | **208 tok/s** MTP (0xSero) |

8k LocalMaxxing 1004.9 tok/s is a **ceiling on a locked-attractor prompt**, not an SLA. See [`refs/context.md`](refs/context.md) and [`refs/speed.md`](refs/speed.md).

Weights we will actually serve are **`dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4`**, not the stock `zai-org/GLM-5.3-Flash` used in the public run. Same architecture; expect a small speed delta, not a different hardware class.

Fallback if Blackwell / SGLang will not boot on Runpod: official vLLM `glm53-flash` image + `UNCENSORED-FP8` on 4× H200. Documented, slower.

## Privacy invariants

These are not optional. A faster setup that breaks one of them is a failed setup.

- Dedicated **Secure Cloud** pod. Never Community Cloud.
- Never **serverless**. Prompts would transit `api.runpod.ai` and be retained.
- Never expose the **HTTP proxy** (`*.proxy.runpod.net`). It is public and unauthenticated.
- Bind the server to `127.0.0.1`. Reach it only via `ssh -L`. Do not `curl` the Tailscale IP, Serve, SOCKS, or Funnel. Tailnet ACL: laptop → pod :22 only.
- Require a bearer token even on localhost.
- In provider-trusted mode, weights normally live on a **network volume** in the same DC and are downloaded once. If customer-visible disk encryption is required, use an encrypted volume disk instead and accept its Pod-lease lifecycle; do not re-pull from Hugging Face on every boot.
- Disable telemetry (`HF_HUB_DISABLE_TELEMETRY=1`, no request logs).
- Do not put `HF_TOKEN` or `RUNPOD_API_KEY` in the container's public env if the console displays it.
- Runpod’s encrypted volume-disk option is provider-managed and has no BYOK; network volumes cannot use that option. This is cold-storage defense in depth, not protection from a privileged host during inference.
- For provider-blind privacy, require CPU/GPU confidential computing, fresh attestation, and attestation-gated key release for the exact deployment. Do not treat Secure Cloud, SSH, or disk encryption alone as sufficient.

Full threat model: [`refs/privacy.md`](refs/privacy.md).

## Next sitting

1. Verify whether Runpod supports provider-blind confidential VM/GPU, attestation, and key release for the exact target GPU/DC.
2. If not, explicitly choose provider-trusted Runpod or move to owned/confidential-compute hardware.
3. Only after that gate, pick A (2× / 200k) or B (4× / 1M). Default B.
4. Confirm Runpod auth (`runpodctl user`) and Secure Cloud stock for that SKU.
5. If provider-trusted and at-rest encryption is required, use an encrypted volume disk rather than a network volume, accepting Runpod-managed keys.
6. Do **not** expose HTTP ports. Jupyter off. SSH only.
7. Pull `dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4` + DFlash2 (`7d74cdd`) onto storage.
8. Boot SGLang bound to `127.0.0.1` at 204800 or 1048576, tunnel with `ssh -L`, measure a prompt **in-band**.
