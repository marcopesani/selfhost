# Reseller pricing — this 4× / 512k boot

Derived 2026-09-04 from our in-band runs. Do not quote 208 or 1004 tok/s into a price. Physics cost is still GPU-seconds on **this** image (no MTP, ADR-023 think processor on) at fully-loaded **$8.42/hr**. The **published list is blended** so a long-context uncensored agent looks like a premium API (even input/output, cache at 10% of input) while the design mix still clears ~20% (ADR-027). Cost-plus-per-meter ($0.35 / $0.038 / $47) is the old ADR-026 table — do not put it on a price page.

Writeup of the decision: ADR-027 (list), ADR-026 (cost basis). Raw timings: [`benchmark.md`](benchmark.md). Pod dollars: [`../runpod/cost.md`](../runpod/cost.md).

## List (what you publish)

Per **million tokens**. Premium uncensored 512k, not Flash.

| Meter | What it is | **List / MTok** |
| --- | --- | ---: |
| **Input** | Prompt tokens that miss prefix cache | **$10.00** |
| **Cached input** | Prompt tokens served from radix / prefix cache | **$1.00** |
| **Output** | All completion tokens, including glm45 thinking | **$20.00** |

2 : 1 output/input. Cached is **10% of input** (same shape as Anthropic cache-read). Reserved alternative (same 20% on the box): **$10.10 / hr**. 24×30 always-on: **$6,062** cost → **$7,272** list.

This is **not** Z.ai Flash ($0.15 / $0.03 / $0.50). It sits next to Opus-class stickers ($5 / $25): we charge **more for the window** (uncensored 512k on a dedicated 4×) and **less of a decode tax** than cost-plus would. If a buyer wants Flash prices, they should buy Flash.

## Why not cost-plus per meter

GPU-second cost on this boot:

| Meter | tok/s | Cost / MTok | Cost+20% |
| --- | ---: | ---: | ---: |
| Input | 8,087 | $0.289 | $0.35 |
| Cached input | 75,000 | $0.031 | $0.038 |
| Output | 60.0 | $39.00 | $47 |

That 134 : 1 output/input ratio is honest physics (decode is slow, prefill is fast) and a terrible consumer page. Publishing $47/MTok next to Z.ai’s $0.50 looks like a gouge even when a real 512k sitting is mostly cached prefix.

Blending moves the margin onto **input and cache** — the thing this SKU actually sells (a private uncensored window). Output is priced like a frontier model, not like 18 minutes of GPU per million tokens.

## Design mix (where 20% is earned)

Busy GPU, `reasoning_effort=max`, one stream. Each turn: **80k cached + 3k new + 4k out** (think + content). 68.1 s/turn → **52.9 turns/hr**.

| Meter | MTok / busy hour |
| --- | ---: |
| Cached input | 4.23 |
| Input | 0.159 |
| Output | 0.211 |

Revenue at $10 / $1 / $20 = **$10.04 / hr** vs $8.42 cost → **19%** (the 20% floor, rounded to consumer figures). Lighter turns (50k cached + 2k new + 2k out) land fatter (~37%). A whole sitting (one ~100k ingest, then 40 cached agent turns) lands ~66% because cache is billed on every turn — that is the intended product.

**Decode-only loses.** 216k output/hr × $20 = $4.32 vs $8.42 cost. A 16k think dump on an 80k prefix is ~−33%. Those buyers take the **$10.10/hr reserved** seat. Do not sell this list to a 65k-think farm.

## Positioning

| Offer | Input | Cached | Output | What it is |
| --- | ---: | ---: | ---: | --- |
| Z.ai GLM-5.3-Flash list | $0.15 | $0.03 | $0.50 | Commodity, censored, batched |
| Claude Sonnet-class | $3 | ~$0.30 | $15 | General premium |
| Claude Opus-class | $5 | ~$0.50 | $25 | Frontier |
| **This list** | **$10** | **$1.00** | **$20** | Uncensored CRACK, 512k, dedicated 4×, provider-trusted |
| ADR-026 cost-plus (do not publish) | $0.35 | $0.038 | $47 | Physics, ugly |

Story for a consumer: you pay for the **uncensored long window**, not a surprise decode meter. Cache hits are a dime on the dollar vs fresh input, same as every hosted API they already know.

## Cost stack (unchanged)

| Line | Rate | Hourly |
| --- | --- | ---: |
| 4× RTX PRO 6000 Secure Cloud | $2.09/GPU-hr (`runpodctl gpu list` 2026-09-04) | $8.36 |
| Volume disk 400 GB, running | $0.10/GB-month | $0.056 |
| Container disk 50 GB, running | $0.10/GB-month | $0.007 |
| **Fully loaded, pod up** | | **$8.42** |

Throughput behind the cost column: ADR-023 briefing **60.0 tok/s** decode, **8,087 tok/s** cold prefill, **75,000 tok/s** cache floor. Decode falls with fill (35.4 @ 655k, 29.4 @ 825k). Deep-window sessions belong on reserved if they are think-heavy.

Do not fold DFLASH2 into a lower output price (CC BY-NC-ND). MTP still blocked (sglang#36599). If MTP serves at 208 tok/s, rewrite ADR-027 — physics cost of output drops to ~$11.24/MTok; the blended list can come down, still not to Flash.

## What to bill

- **Input** — cache miss.
- **Cached input** — prefix-cache hit. SGLang `prompt_tokens_details` was **`null`** on our streams. A gateway must hash prefixes or this list overcharges every follow-up as $10 input (and undercharges relative to the design mix if you then “eat” cache). The $1 cache meter is load-bearing.
- **Output** — every completion token: reasoning, content, tool-call JSON. Thinking is not free.
- One 512k stream. Leftover VRAM is short-prompt concurrency, not a second full-window tenant.

## Occupancy (shared always-on)

Busy list earns ~20% only while the box is full of the design mix. Empty hours are a loss. Shared warm API at **70% fill**, same blend scaled: **$14 / $1.40 / $29**. Prefer **reserved $10.10/hr** for one research tenant.

## Worked checks (published list)

Revenue uses $10 / $1 / $20. Cost uses $8.42/hr × e2e.

| Request | Tokens | e2e | Revenue | GPU cost | vs 20% |
| --- | --- | ---: | ---: | ---: | --- |
| ADR-023 cold briefing | 94,490 in + 2,348 out | 50.8 s | $0.99 | $0.119 | fat (ingest pays for the window) |
| Prefix-cached follow-up | 95,915 cached + 122 out | 2.94 s | $0.098 | $0.0069 | fat (cache meter) |
| Design-mix busy hour | 0.159 + 4.23 cached + 0.211 out MTok | 3600 s | $10.04 | $8.42 | **~19%** |
| 16k think on 80k prefix | 2k in + 80k cached + 16k out | ~268 s | $0.42 | $0.627 | **loss — reserved** |

## Commercial rails (not priced, still binding)

- Serve path stays ADR-003 / 011 / 012: `ssh -L` (or Tailscale `:22` + `-L`), no proxy URL, no serverless.
- Provider-trusted (ADR-016). Do not sell this as provider-blind.
- Confirm the **dealignai** UNCENSORED checkpoint’s license allows the commercial serve. Stock Flash is MIT; the CRACK is a derivative.
- Do not enable DFLASH2 on a paid path (CC BY-NC-ND).
- Do not advertise 1M (ADR-025).

## When to rewrite this

New ADR, not a silent edit: design mix measured from a live meter (not this constructed agent hour); MTP actually serving; DFLASH with a commercial license; GPU or storage rate change; selling decode-only and losing.
