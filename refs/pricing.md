# Reseller pricing — this 4× / 512k boot

Derived 2026-09-04 from our in-band runs, not from Z.ai or 0xSero. Do not quote 208 or 1004 tok/s into a price. Math: GPU-seconds per token type on **this** image (no MTP, ADR-023 think processor on), fully-loaded pod dollars, then **+20%**. Round the list **up** so the floor is cleared.

Writeup of the decision: ADR-026. Raw timings: [`benchmark.md`](benchmark.md). Pod dollars: [`../runpod/cost.md`](../runpod/cost.md).

## List (metered, busy GPU)

Per **million tokens**. 20% margin on fully-loaded cost while the GPUs are doing that work. One tenant / one long stream.

| Meter | What it is | tok/s used | Cost / MTok | **List / MTok** |
| --- | --- | ---: | ---: | ---: |
| **Input** | Prompt tokens that miss prefix cache | 8,087 | $0.289 | **$0.35** |
| **Cached input** | Prompt tokens served from radix / prefix cache | 75,000 | $0.031 | **$0.038** |
| **Output** | All completion tokens, including glm45 thinking | 60.0 | $39.00 | **$47** |

Reserved alternative (same 20%): **$10.10 / hr** for the box, tokens optional. 24×30 always-on: **$6,062** cost → **$7,272** list.

## Do not compete with Z.ai on $/MTok

Z.ai / OpenRouter GLM-5.3-Flash (2026-09): list **$0.15 / $0.50 / $0.03**, launch promo **$0.075 / $0.25 / $0.015** through 2026-09-09 UTC+8. Our output list is ~**94×** their list. That is the physics of one 4× dedicated stream vs a batched cluster, not a rounding error.

This SKU sells **uncensored CRACK + 512k + provider-trusted path**, not cheap Flash. If a buyer wants Z.ai prices, they should buy Z.ai.

## Cost stack

| Line | Rate | Hourly |
| --- | --- | ---: |
| 4× RTX PRO 6000 Secure Cloud | $2.09/GPU-hr (`runpodctl gpu list` 2026-09-04) | $8.36 |
| Volume disk 400 GB, running | $0.10/GB-month | $0.056 |
| Container disk 50 GB, running | $0.10/GB-month | $0.007 |
| **Fully loaded, pod up** | | **$8.42** |

Stopped volume disk is **$0.20/GB-month** ($80/mo on 400 GB). A reseller API keeps the pod **up**; do not price as if we stop between requests. Cold SGLang reload is ~11 min (~$1.54) plus JIT prefill (first 22k ingest was ~355 tok/s, not the 8.1k figure).

Formula: `cost_per_MTok = 8.42 × 1e6 / (tok_s × 3600)`. List = that × 1.20, rounded up.

## Throughput this list is built on

Consumer boot (ADR-023): TileLang DSA, bf16 KV, think-budget logit processor, **no MTP**. API window 512k (ADR-025). Protocol: SSE + `include_usage`. Decode = `(completion_tokens − 1) / (t_last − t_first)`. Prefill from TTFT on a **cold unique** corpus.

| Meter | Measurement | Why this number |
| --- | --- | --- |
| Output **60.0 tok/s** | 94,490 prompt, 2,348 out, `finish=stop` after ADR-023 reboot | Actual daily-job decode with the processor on. Short-prompt 90.6 and all-think 83.2 were the **previous** boot. |
| Input **8,087 tok/s** | same request, TTFT 11.68 s | Honest cold prefill. Do not use the first-request 22k @ ~355 tok/s (JIT). |
| Cached **75,000 tok/s** | conservative floor from paired warm TTFTs | ADR-023 follow-up: 95,915 prompt in 1.20 s after ~1.4k new tokens → ~93k tok/s implied cache. Earlier pair (91,759 in 1.23 s, ~20 new) → ~74k apparent. 75k keeps per-request overhead at a ~95k prefix. |

Decode falls with fill: **35.4 tok/s** at 655k, **29.4 tok/s** at 825k. At a packed 512k window interpolate ~42 tok/s. The $47 output list is a **~100k-context** number. Deep-window sessions compress margin unless the buyer is on the reserved hour or you use the 70% occupancy list below.

Do not fold DFLASH2 into a lower output price. The draft is **CC BY-NC-ND**. Native MTP is still blocked (sglang#36599). If a later image holds MTP at the published 208 tok/s, output cost becomes ~$11.24/MTok and list **$13.50** — still ~27× Z.ai list. Write a new ADR; do not silently cut.

## What to bill

- **Input** — new prompt tokens (cache miss).
- **Cached input** — prefix-cache hit. SGLang `prompt_tokens_details` was **`null`** on our streams. A reseller gateway must hash prefixes (or wait for a usage field) or it will either give cache away or overbill input.
- **Output** — every completion token: reasoning, content, tool-call JSON. `reasoning_effort=max` is the uncensor default (ADR-010). Thinking is not a free meter.
- One 512k stream. At ~94k we sat ~84 GB/GPU; at 825k, 97 GB. A second full-window chat does not fit. Leftover VRAM is short-prompt concurrency, not a second 512k tenant.

## Occupancy (shared always-on)

Busy-GPU list above earns 20% only while the box is working. Empty hours are a loss. If this is a **shared** warm API, load the same cost at **70% fill** then +20%:

| Meter | List / MTok |
| --- | ---: |
| Input | **$0.50** |
| Cached input | **$0.054** |
| Output | **$67** |

Prefer **reserved $10.10/hr** when the buyer is one research tenant. Capacity is one long stream; multiplexing 512k agents on this SKU is a QoS problem, not a volume play.

## Worked checks (busy list vs measured wall time)

Revenue uses $0.35 / $0.038 / $47. Cost uses $8.42/hr × e2e.

| Request | Tokens | e2e | Revenue | GPU cost | vs 20% |
| --- | --- | ---: | ---: | ---: | --- |
| ADR-023 cold briefing | 94,490 in + 2,348 out | 50.8 s | $0.143 | $0.119 | ~21% |
| Prefix-cached follow-up | 95,915 cached + 122 out | 2.94 s | $0.0094 | $0.0069 | fat (75k cache is conservative) |
| Wave-2 last healthy | ~16k in + ~809k cached + ~214 out | ~13.7 s | ~$0.047 | $0.032 | fat on cache; **thin on decode** (29.4 tok/s) |

A coding-agent hour (~105 turns, 50k cached + 2k new + 2k out each) bills ~$10.15 vs $8.42 cost — the output meter carries almost all of it. That mix is this SKU’s job (ADR-019).

## Commercial rails (not priced, still binding)

- Serve path stays ADR-003 / 011 / 012: `ssh -L` (or Tailscale `:22` + `-L`), no proxy URL, no serverless. A public `*.proxy.runpod.net` meter would reverse privacy ADRs.
- Provider-trusted (ADR-016). Do not sell this as provider-blind.
- Confirm the **dealignai** UNCENSORED checkpoint’s license allows the commercial serve you are selling. Stock Flash is MIT; the CRACK is a derivative.
- Do not enable DFLASH2 on a paid path (CC BY-NC-ND).
- Do not advertise 1M (ADR-025).

## When to rewrite this

New ADR, not a silent edit: MTP actually serving; DFLASH with a commercial license; occupancy measured from a live meter; GPU or storage rate change; a second concurrent 512k stream proven in VRAM.
