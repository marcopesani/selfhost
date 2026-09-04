# Abliterated / uncensored GLM-5.3-Flash

Researched 2026-09-02. Hugging Face catalog search found **37** repos; they collapse to **four families**. Most of the rest are requants or mirrors.

## Winner

**`dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4`** (loop-fixed 2026-08-29, re-touched 2026-09-02). The `ABLITERATED-NVFP4` twin is advertised as the same CRACK but the commits differ (`f75389c` vs `a180a2f`) — **pin UNCENSORED, do not mix**.

**Do not use `rbinrs/GLM-5.3-Flash-ABLITERATED-NVFP4`.** It is a stale 2026-08-28 snapshot from *before* the loop fix (older MMLU, missing `model-input-scales.safetensors`, vision-stub chat template).

Pair with draft **`incoai/GLM-5.3-Flash-DFlash2`** (CC BY-NC-ND; pin `7d74cdd`). DFLASH and native MTP are alternate spec paths — do not enable both.

Why this one for *this* project (Runpod + max tok/s + actually uncensored at default settings):

- Weight-level CRACK, not a system prompt, LoRA, or template jailbreak
- **HarmBench-320 = 0% refusal** at reasoning-off and **max (default)**
- MTP head is also cracked (81.7% acceptance) so spec decode does not collapse on the prompts a stock model refuses
- Vision tower retained byte-identical
- Ungated
- NVFP4 is the format the 300–1000 tok/s SGLang runs use
- MMLU 85.28% vs base 86.16% (−0.88 pp) — quality intact

Hopper fallback of the same family: **`dealignai/GLM-5.3-Flash-UNCENSORED-FP8`**. MMLU **87.33% vs base 86.74% (+0.59)**. HarmBench 320/320. MTP 75.9%. Native FP8 on H200. Use this if we land on 4× H200 instead of RTX PRO 6000.

## How reasoning effort interacts

dealignai left **low** effort conservative on purpose (quality). Published refusal:

| Mode | dealignai NVFP4 refusals | Use? |
| --- | --- | --- |
| off | 0% | yes |
| **max (default)** | **0%** | **yes — default** |
| high | ~4% | ok |
| low | ~9% | do not use if you want full uncensor |

Always pass `reasoning_effort=max` or omit it. Never default clients to `low`.

## The other families

### orcarouter (popular, weaker uncensor)

`orcarouter/GLM-5.3-Flash-Uncensored-FP8` (gated) and `-NVFP4` / GGUF / MLX.

Independent single-direction abliteration (Arditi et al.), baked into official block-FP8 shards. Their own evals at **`reasoning_effort=low`**:

| Bench | Base refuse | After |
| --- | ---: | ---: |
| MaliciousInstruct | 96% | **11%** |
| JailbreakBench | 93% | **12%** |
| HarmBench standard | 93% | **18%** |
| StrongREJECT | 99% | **27%** |
| XSTest over-refusal | 2.4% | 0.4% |

They argue Z.ai's alignment is **not** a single linear direction — leftover categories will not die no matter how you sweep layers. Their NVFP4 of this FP8 leaves **more** residual (JBB harmful refuse 0.172). **MTP dropped by default** on that NVFP4. Capability ±1.5 pp.

More likes than dealignai. Worse for "I want it to just answer." Do not pick this as primary.

### Blackfrost DERISKED

`Blackfrost-AI/GLM-5.3-Flash-DERISKED-{BF16,NVFP4,GGUF}`. Proprietary method, not disclosed. R1-HARMFUL-BENCH-450: **4/300 harmful refusals (1.3%)** at max thinking. Validated SGLang 8× B200 ~165 tok/s, spec off. MTP present but unused in their recipe. Used by drowzeys as a *direction reference*, not the body they shipped. Fine as a research alternate; not the speed-track pick.

### drowzeys keys (layer splice)

`drowzeys/keys-GLM-5.3-Flash-NVFP4-ablit-l15-45-anchorstock` and earlier `l15-43-mtp-l45`. RedHat NVFP4 body + dealignai `o_proj` on L15–43 + MTP L45; L0–14 stock. Gate 32/32 bypass. Built for Spark / custom vLLM, not the stock SGLang speed recipe.

## Do not use / do not confuse

| Repo | Why |
| --- | --- |
| `dealignai/GLM-5.3-ABLITERATED-NVFP4` (no "Flash") | **753B GLM-5.3**, different model |
| `dealignai/GLM-5.3-CYBERSECURITY-FP8` | Same 753B family; 8× H200 @ 131k in their recipe — see [`red-team.md`](red-team.md) |
| `msuiche/GLM-5.3-Flash-abliterated-cyber-GLP-44` | Gated **GLP steering** for Flash, not a LoRA. Do not mix with CRACK (ADR-020) |
| `msuiche/…-cyber-GLP-77` | Steering vector for **753B**, not Flash |
| `MorinoNushi/GLM-5.3-Flash-Heretic-LoRA-V1-GGUF` | Rank-1 llama.cpp abliteration; 26% residual. Not SGLang, not cyber SFT |
| Random FP8/NVFP4/W4A16 mirrors (`AIAgens`, `0xSojalSec`, `nuottroisaoduoc`, …) | Reuploads, no evals |
| `rbinrs/GLM-5.3-Flash-ABLITERATED-NVFP4` | Stale pre-08-29 loop-fix mirror |
| `orcarouter` GGUF/MLX/EXL3 requants | Wrong engine for the tok/s goal |
| `grant-ai` MLX 4bit | Mac path; derived from Blackfrost |
| Stock `zai-org/GLM-5.3-Flash` | Heavy over-refusal (the problem) |

## Catalog (families only)

HF search 2026-09-02. Downloads are last-month.

| Family | Canonical ids | Quant | Gated | Uncensor (author) | MTP | Speed-track? |
| --- | --- | --- | --- | --- | --- | --- |
| dealignai CRACK | `…-ABLITERATED-FP8` / `…-UNCENSORED-FP8` | FP8 | no | HarmBench 0% off/max | yes, cracked | Hopper fallback |
| dealignai CRACK | **`…-UNCENSORED-NVFP4`** (twin: `…-ABLITERATED-NVFP4`, do not mix) | NVFP4 | no | HarmBench 0% off/max | yes, cracked | **primary** |
| orcarouter | `orcarouter/GLM-5.3-Flash-Uncensored-FP8` | FP8 | auto | 11–18% residual | yes | no |
| orcarouter | `…-Uncensored-NVFP4` | NVFP4 | auto | residual worse | dropped | no |
| Blackfrost | `Blackfrost-AI/…-DERISKED-NVFP4` | NVFP4 | no | 1.3% | present, unused | alternate |
| drowzeys | `keys-…-ablit-l15-45-anchorstock` | NVFP4 splice | some gated | 32/32 | spliced | Spark only |

## Serve notes

dealignai NVFP4 (vLLM, Hopper Marlin):

```bash
vllm serve dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4 \
  --tensor-parallel-size 4 --moe-backend marlin \
  --tool-call-parser glm47 --reasoning-parser glm45 --enable-auto-tool-choice \
  --speculative-config '{"method":"mtp","num_speculative_tokens":1}'
```

On Blackwell + SGLang, ignore `--moe-backend marlin` and use the speed-track command in [`speed.md`](speed.md).
