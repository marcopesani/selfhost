# Context — 200k or 1M, nothing smaller

Clamped 2026-09-03. Architecture from `zai-org/GLM-5.3-Flash` `config.json`. VRAM from LocalMaxxing 2× NVFP4 peaks plus 0xSero’s 4× fp8 KV pool.

## Why 8k / 32k / 64k are out

The checkpoint’s `max_position_embeddings` is **1,048,576**. The hybrid stack (34 KDA layers + 11 sparse MLA layers, `index_topk=2048`) exists so decode does not pay dense-MHA cost on that window.

LocalMaxxing’s 300–1004 tok/s family is **ctx=8192**, prompt 403–2048. Our
previous recipe used a **64k** pool. Neither is a serve target. Prefill of a
real 200k/1M prompt is the workload; a sub-200k pool throws most of the model
away.

Two legal SKU windows (ADR-013), plus **this boot’s honest API window** (ADR-025):

| Band | Flag | Why this number |
| --- | ---: | --- |
| **200k** | `--context-length 204800` | 200×1024, divides 64/256 page sizes (`200000` does not). Same class as published 229k–262k 2× runs. |
| **512k (this 4× boot)** | `--context-length 524288` | Half of native 1M. Below the DSA-indexer OOM cliff (~655k–825k). Clients can fill the bar to 100% without killing SGLang. |
| **1M** | `--context-length 1048576` | Native `max_position_embeddings`. Do not serve on this image until a chat holds it. |

ADR-013 said not to add a third band. ADR-025 does, for usage UX: advertising 1M while the process dies at ~825k makes the usage meter a lie.

## Architecture that makes long ctx cheap

| Piece | Count | How memory scales |
| --- | ---: | --- |
| KDA linear-attn | 34 | Recurrent state, **O(1) per sequence** (~64 MiB bf16 for 64×128×128×34). Not the 1M problem. |
| Sparse MLA (DSA) | 11 | Compressed latent `kv_lora_rank=512`, `qk_rope_head_dim=0` (NoPE). Plus indexer (`index_n_heads=32`, `index_head_dim=128`, `index_kpool=4`, `index_topk=2048`). **O(n)** but n is 11 layers, not 45. |
| Decode attention | top-k 2048 | Decode compute stays bounded; prefill and indexer scan still grow with n. |

Empirical KV (MLA + indexer + page overhead) from 0xSero: **3,789,184
tokens ≈ 28 GB per rank at fp8_e4m3** → **~7.4 KB/token/rank**. A tensor
parallel deployment allocates a same-sized cache slab on every rank, so total
GPU memory is multiplied by TP width. bf16 is roughly **14.8 KB/token/rank**.

| Window | fp8 / rank | fp8 total TP2 | bf16 / rank | bf16 total TP2 | bf16 total TP4 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 204,800 | 1.5 GB | 3.0 GB | 3.0 GB | 6.1 GB | 12.1 GB |
| 1,048,576 | 7.8 GB | 15.5 GB | 15.5 GB | 31.0 GB | 62.1 GB |

Dense MHA at 1M would be hundreds of GB. This model’s 1M tax is **tens of
GB across the GPUs**, not a second copy of the weights. The 2× box is
weight-bound at 200k and cannot hold the 1M pool with this NVFP4 target.

## Boot VRAM (SGLang preallocates the pool)

SGLang allocates `--max-total-tokens` at init. Do not add KV onto an 8k
*peak*; replace the tiny 8k pool.

Base: 2× NVFP4 + DFLASH k=8 peak **182.2 GB total** at ctx 8192
(LocalMaxxing `cmthnezqy…`). The 8k TP2 KV pool is only ~0.1 GB total, so
that figure is essentially weights + draft (2.34 GB) + graphs. The following
is an extrapolation from the published per-rank KV rate, not a boot log; DFLASH
buffers and allocator fragmentation can make the real budget larger.

| SKU | Window | KV dtype | Estimated boot | Fits? |
| --- | --- | --- | ---: | --- |
| 2× 96 GB (192) | 200k | bf16 | ~188 GB | **Tight**, ~4 GB spare; unverified |
| 2× 96 GB (192) | 200k | fp8 | ~185 GB | Tight, ~7 GB spare; unverified |
| 2× 96 GB (192) | 1M | fp8 | ~198 GB | **No**, ~6 GB over |
| 2× 96 GB (192) | 1M | bf16 | ~213 GB | **No**, ~21 GB over |
| 4× 96 GB (384) | 200k | bf16 | ~194 GB | Yes, leftover is for concurrency |
| 4× 96 GB (384) | 1M | bf16 | ~244 GB | **Yes**, ~140 GB spare |
| 4× H200 (564) | 1M | bf16 | ~306 GB weights + KV | Yes (Hopper fallback) |

k=64 / n-gram buffers pushed the same 2× box to 188 GB at 8k. Keep
DFLASH at **k=8** on 2×. Treat 200k as a tight bring-up; use fp8 KV or drop
the draft (MTP only) if the real allocator cannot produce the full pool.

## What is actually published in-band

Filter: window ≥ 200k, or 1M configured. 8k DFLASH numbers are **not** the SLA.

| tok/s | Window | Hardware | Quant | Spec | Source | Honest read |
| ---: | ---: | --- | --- | --- | --- | --- |
| **208** | 1M configured | 4× RTX PRO 6000 | NVFP4 | NEXTN MTP5 | [0xSero](https://github.com/0xSero/glm-5.3-flash-sglang-sm120) | Only published NVFP4 + 1M Blackwell number. Single stream; prompt length not stated. |
| 143 | 1M configured | 4× RTX PRO 6000 | NVFP4 | NEXTN MTP5 | 0xSero | `reasoning_effort=low` — do not use |
| 154 / 149 / 142 | 229k | 2× RTX PRO 6000 | **EXL3-4bit** | DFlash2 | LocalMaxxing | Same GPU count, **not our checkpoint**. Decode band for “2× long ctx” |
| 150 | 353k | 2× RTX PRO 6000 | EXL3-4bit | MTP | LocalMaxxing | 2× can hold ~350k of a smaller quant |
| — | 256k, 16 seqs | 4× RTX PRO 6000 | NVFP4 | MTP3 / DFlash2-7 | [rtx6kpro](https://github.com/local-inference-lab/rtx6kpro/blob/master/models/glm-5.3-flash.md) | Qualified 200k-class on 4×; not a tok/s claim |
| 47–80 | 262k–1M | DGX Spark | EXL3 / NVFP4 | mixed | tonyd2wild / cfontes / LM | Wrong hardware class |
| 300–1004 | **8k** | 2× RTX PRO 6000 | NVFP4 | DFLASH2 | LocalMaxxing | Out of band. Do not quote as 200k/1M decode |

No published **NVFP4 + 2× + 200k/1M** boot. 200k on 2× NVFP4 is a tight
arithmetic estimate, not a log.

vLLM on SM120 at TP=2 has a measured **184,755-token** fp8 pool with `max_model_len=163840` ([vllm#53963](https://github.com/vllm-project/vllm/issues/53963)). That is a configured 160k window on a different engine, not a hard NVFP4 ceiling.

## Prefill is the real 1M cost

Sparse decode stays in the same band as a filled 200k cache (`index_topk=2048`). Prefill does not.

At 2,000–4,500 tok/s prefill (LocalMaxxing ceiling prefill was 4460 on a 403-token prompt — optimistic):

| Prompt | TTFT @ 2000 tok/s | @ 4460 tok/s |
| ---: | ---: | ---: |
| 200k | ~100 s | ~45 s |
| 1M | ~500 s | ~235 s |

Chunked prefill is required. Runpod’s HTTP proxy 100 s timeout is another reason the API stays on `ssh -L` (ADR-003). Do not treat “1M configured” as “1M filled every request.”

## Two serve configs (pick one at provision)

### A — 200k on 2× (cost)

Use if prompts will not exceed ~200k. NVFP4 + DFLASH k=8 is expected to fit
but is tight on bf16 KV; this is the experimental/cost option, not the proven
native-window option.

```text
--tp-size 2
--context-length 204800
--max-total-tokens 204800
--kv-cache-dtype bfloat16
--speculative-num-draft-tokens 8
```

If boot OOM: `--kv-cache-dtype fp8_e4m3`, then drop DFLASH and use NEXTN/MTP.
If the pool is still short of 204800, this SKU is dead and we go to B.

### B — 1M on 4× (native window)

Use if we want the model’s actual context. Proven (0xSero). bf16 KV is fine; do not depend on unverified sm_120 fp8 KV.

```text
--tp-size 4
--context-length 1048576
--max-total-tokens 1048576
--kv-cache-dtype bfloat16
--mem-fraction-static 0.85
```

Boot **NEXTN/MTP** first (208 tok/s published). Add DFLASH2 k=8 only after a 1M-capable completion. Do not start at k=64.

Hopper fallback is still **4× H200** + `UNCENSORED-FP8` + `--max-model-len 1048576`. 2× H200 cannot hold FP8 weights (~306 GB).

## Do not

- Do not serve a sub-200k pool; the old 8k/64k/128k attempts are retired.
- Buy 4× and then clamp the window to 200k unless we want **concurrency** (several 200k seqs). One stream at 200k does not need 4×.
- Plan 1M on 2× NVFP4.
- Switch to EXL3 just to squeeze 1M onto 2× (ADR-010 pins NVFP4).
- Quote 1004 or 300–391 tok/s as the long-context SLA.
