# Agent instructions

This directory is a **scratchpad**, not a product repo. Your job in a new session is to continue the self-host of GLM-5.3-Flash abliterated on Runpod without losing privacy or the speed target. This boot’s API window is **512k (`524288`)** (ADR-025). SKU menu remains 200k or 1M (ADR-013); do not advertise 1M here.

## First 60 seconds

1. Read [`STATUS.md`](STATUS.md). That is the live truth.
2. Read [`DECISIONS.md`](DECISIONS.md). Do not reverse an ADR without writing a new one.
3. If the user mentions a past sitting, read the latest file in [`sessions/`](sessions/) (local-only; gitignored).
4. Check [`runpod/inventory.md`](runpod/inventory.md) (shape) and local `.env` / `runpod/inventory.local.md` (live IDs) before creating any billable resource.
5. Speed / checkpoint / privacy / context / research-workload / **reseller $/MTok** answers are already in `refs/speed.md`, `refs/abliterated.md`, `refs/privacy.md`, `refs/context.md`, `refs/red-team.md`, `refs/ops.md`, `refs/pricing.md`. Do not re-litigate them without new measurements. Do not revive an 8k/64k pool. Do not swap this 4× pod to GLM-5.3 753B or a scanner image (ADR-019). Do not `--enable-lora` (ADR-020). Do not install `pi-webxp` / CAI / Strix on this guest; red-team package is casefile + xtodo, `/xp lite` (ADR-021). Do not add Grafana or pi HTTP dashboards; ops is snapshot + `/ops` skill (ADR-022). Do not lower the 65k omit-cap or `--allow-auto-truncate` (ADR-023). This boot serves **512k** (ADR-025), not 1M and not a 256k client-only cap. Reseller list is **$0.35 / $0.038 / $47** per MTok (ADR-026) — do not price from Z.ai or 208 tok/s. Never scrape `/get_server_info` or loop `/health`.

## Hard rules

- Do not create a Community Cloud pod.
- Do not create a serverless endpoint for this model. Prompts would leave the pod through Runpod's invoke API.
- Do not add HTTP ports to the pod. Do not hand the user a `*.proxy.runpod.net` URL.
- Do not bind vLLM/SGLang to `0.0.0.0`. Userspace Tailscale already rewrites tailnet ports onto localhost — close that with ACL :22, not by advertising the API.
- Do not commit `.env`, `secrets/`, API keys, SSH keys, or model weights.
- Do not commit live instance identifiers: pod id, template id, public IP, SSH port, or SSH key paths. Those belong in `.env` (`RUNPOD_POD_ID`, `RUNPOD_TEMPLATE_ID`, `SSH_HOST`, `SSH_PORT`) and optional `runpod/inventory.local.md`. Session notes are gitignored for the same reason.
- Do not call ordinary Runpod provider-blind. Its optional volume-disk encryption is Runpod-keyed, has no BYOK, and does not protect plaintext in guest/GPU memory. If provider-blind privacy is required, do not provision until CPU/GPU confidential computing, attestation, and gated key release are verified.
- Do not skip the cost guard. A 2× or 4× RTX PRO 6000 pod bills by the second while running. Set `--terminate-after` on experimental pods; stop or delete when a sitting ends unless the user says keep it warm. Do not buy 4× for one 200k stream.
- Do not treat "Running" in the console as success. Success is a completion returned over the SSH tunnel.

## What to write down

Every sitting that changes state must:

1. Create or update a local `sessions/YYYY-MM-DD-<slug>.md` from [`sessions/_template.md`](sessions/_template.md). Session notes are gitignored — they pick up live SSH endpoints.
2. Update `STATUS.md` (what exists, what failed, next action). No pod ids, IPs, or SSH ports.
3. If a resource was created or destroyed, update local `runpod/inventory.local.md` and `.env`. Keep tracked `runpod/inventory.md` as the empty shape.
4. If an architecture choice changed, add an ADR in `DECISIONS.md`.
5. If a measurement was taken, append a row to `refs/benchmark.md` (our runs section) and drop the raw JSON in `logs/` (gitignored).

## Provision order

Volume first, then compute in that same data center. Never the reverse.

```text
verify provider-blind support or explicitly record provider-trusted mode
→ pick A (2× / 200k) or B (4× / 1M; default)
→ pick DC with that SKU on Secure Cloud
→ create High-Performance network volume there
→ create pod attached to that volume, SSH only, no HTTP ports
→ download weights once onto the volume
→ start SGLang on 127.0.0.1 at 204800 (config A) or **524288** (this 4× boot, ADR-025). 1048576 only after a new ADR if the indexer holds a 1M chat.
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
| ~160–210 tok/s | 200k/1M unknown | dealignai FP8 + MTP on 4× H200; short-prompt only |

Historical 8k DFLASH results (300–1004 tok/s, including best-of-N and
attractor runs) are ceiling provenance only. They are out of band and never
count as the 200k/1M SLA.

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
