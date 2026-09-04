# Benchmarks

In-band means the engine is configured at **200k or 1M** (ADR-013) and the prompt is not a 403-token 8k attractor. Do not mix 8k DFLASH ceiling numbers into this table. Reseller $/MTok from these rows: [`pricing.md`](pricing.md) (ADR-026).

## Published (not ours)

| tok/s out | Window | Hardware | Spec | Source | Notes |
| ---: | --- | --- | --- | --- | --- |
| 208 | 1M configured | 4× RTX PRO 6000 | NEXTN MTP5 | 0xSero | In-band published. Not this sitting (our image cannot load MTP, sglang#36599) |
| ~140–154 | 229k–353k | 2× RTX PRO 6000 | EXL3 | LocalMaxxing | Analog, not NVFP4 |
| 300–1004 | 8k | 2× RTX PRO 6000 | DFLASH2 | LocalMaxxing | Out of band. Do not quote as SLA |

## Our runs

Protocol: SSE stream + `include_usage`. **Decode tok/s** = `(completion_tokens − 1) / (t_last − t_first)`. Discard 32-token warmup (noisy). All generated tokens were reasoning (`glm45`). **No MTP.**

| When | tok/s out | TTFT | VRAM | prompt tok | completion tok | notes |
| --- | ---: | ---: | --- | ---: | ---: | --- |
| 2026-09-04 | **90.6** (mean of 3) | 0.50–0.54 s | ~82 GB × 4 | 34 | 256 | Greedy. 90.9 / 90.3 / 90.7. 1M pool, TileLang + bf16 KV. Raw: [`logs/2026-09-04-toks.json`](../logs/2026-09-04-toks.json) |
| 2026-09-04 | 86.2 | 1.03 s | same | 7725 | 256 | Prefix-cache likely. Decode only; do not treat TTFT as cold prefill |
| 2026-09-04 | 86.1 | 1.03 s | same | 22025 | 256 | Same. Prefix-cached vs the earlier cold 22k |
| 2026-09-04 | n/a decode | ~62 s e2e | same | **22023** | 64 | **Cold** 22k ingest. ~355 prompt tok/s if almost all of 62 s is prefill. First-request JIT; not the 91k figure. [`logs/2026-09-04-inband-long.json`](../logs/2026-09-04-inband-long.json) |
| 2026-09-04 | **83.2** | **9.70 s** | same | **91739** | 1024 (all think) | Cold unique corpus: 47 repo text files (~345 kB), no `.env`. Prefill from TTFT ≈ **9.5k tok/s**. [`logs/2026-09-04-longctx-repo-summary.json`](../logs/2026-09-04-longctx-repo-summary.json) |
| 2026-09-04 | 82.4 | 1.23 s | same | 91759 | 1536 (860 think) | Same corpus, prefix-cached follow-up so a briefing could start. Hit `length` mid-ADR list. |
| 2026-09-04 | **60.0** | **11.68 s** | ~84 GB × 4 | **94490** | 2348 (`finish=stop`) | Cold unique corpus after ADR-023 reboot: 48 files, ~355 kB, no `.env`. Think budget 4096 / cap 8192 — briefing finished. Prefill from TTFT ≈ **8.1k tok/s**. Decode slower than the 83.2 all-think run (custom logit processor on). [`logs/2026-09-04-longctx-adr023.json`](../logs/2026-09-04-longctx-adr023.json) |
| 2026-09-04 | 69.4 | 1.20 s | same | 95915 | 122 | Same corpus + first briefing in history; prefix-cached. |
| 2026-09-04 | 68.0 → **29.4** | 0.50 → **6.45 s** | 80 → **97.0 GB** × 4 | **825511** | ~214 JSON | Long chat from the briefing, 16k fills, 38 batches + seed. **39/39** needle/JSON checks. Next 16k prefill: DSA indexer CUDA OOM 12.86 GiB. Not 1M. [`logs/2026-09-04-longchat-1m-wave2.json`](../logs/2026-09-04-longchat-1m-wave2.json) |
| 2026-09-04 | 35.4 | 20.0 s | 95 GB × 4 | 655512 | 269 | Same protocol, 100k fills. Died on the next turn (11.77 GiB). [`logs/2026-09-04-longchat-1m.json`](../logs/2026-09-04-longchat-1m.json) |

Engine: `lmsysorg/sglang:glm-5.3-flash@sha256:a2c0f7d4…` on 4× RTX PRO 6000 Blackwell Server Edition (Secure Cloud). After ADR-023: `max_prefill_tokens=131072`, `chunked_prefill_size=16384`. No MTP. A 1M-configured pool still OOMs the DSA indexer in a live chat at **~825k** (16k new tokens) or **~655k** (100k new tokens).
