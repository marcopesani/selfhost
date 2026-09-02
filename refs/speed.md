# Speed — squeeze tok/s out of GLM-5.3-Flash

Researched 2026-09-02. Sources in [`links.md`](links.md). Frozen LocalMaxxing dump: [`snapshots/`](snapshots/).

## What the headline number actually is

[LocalMaxxing run `cmtk0maew03mrp701oyaivvka`](https://www.localmaxxing.com/en/models/zai-org/GLM-5.3-Flash?run=cmtk0maew03mrp701oyaivvka) is **1004.89 tok/s out**, 4460 prefill, 125 ms TTFT, 187.9 GB VRAM, batch 1, ctx 8192, 403→2048.

Stack: **SGLang + DFLASH2 + ModelOpt NVFP4 + TP=2 on 2× RTX PRO 6000 Blackwell 96 GB**.

The submitter's notes say this is **not** a normal chat workload:

- width-64 speculative chains filled by period-aligned 32-gram n-gram proposals
- "n-gram primary mode skips the draft forward entirely on complete proposals"
- acceptance **64/1.00 on a locked attractor**
- clocks locked 3090 MHz core / 14 GHz mem / 450 W
- presharded NVMe load, staged PCIe all-reduce
- best-valid-of-6 with 45 s cooldowns

Treat **1004** as a ceiling on a synthetic attractor. Same hardware + engine without that trick lands in a different band (see table).

## Published numbers that look real

| tok/s out | Hardware | Engine | Quant | Spec | Ctx | Source | Notes |
| ---: | --- | --- | --- | --- | ---: | --- | --- |
| 1004.9 | 2× RTX PRO 6000 | SGLang | NVFP4 | DFLASH2 k=64 | 8k | LocalMaxxing `cmtk0maew…` | Attractor / n-gram skip-draft / clock lock. GPU power only 228 W |
| 808.5 | 2× RTX PRO 6000 | SGLang | NVFP4 | DFLASH2 k=28 + n-gram | 8k | `cmtjf2ynj…` | Clock lock + n-gram hybrid. Not Runpod |
| 514 / 482 / 443 | 2× RTX PRO 6000 | SGLang | NVFP4 | DFLASH2 k=20/20/12 | 8k | same user | **best-of-N**. Notes say **steady-state 373–391** |
| **300.7** | 2× RTX PRO 6000 | SGLang | NVFP4 | DFLASH2 **k=8** | 8k | `cmthnezqy…` | **Least-gamed same-stack number. Start here** |
| **208** | 4× RTX PRO 6000 | SGLang | NVFP4 | NEXTN MTP5 | 1M | [0xSero](https://github.com/0xSero/glm-5.3-flash-sglang-sm120) | Default reasoning, single stream. Stock-image-safe fallback |
| 143 | 4× RTX PRO 6000 | SGLang | NVFP4 | NEXTN MTP5 | 1M | 0xSero | `reasoning_effort=low` |
| **211** | 4× H200 (implied TP4) | vLLM | FP8 | MTP k=1 | — | dealignai FP8 card | Single stream |
| 163 | 4× H200 | vLLM | FP8 | none | — | dealignai FP8 card | Baseline |
| 166 | 8× B200 | SGLang | NVFP4 | off | — | Blackfrost DERISKED card | Single stream observation |
| 145–151 | 2× RTX PRO 6000 | custom vLLM/B12X | EXL3 TR3 | DFlash2-7 | 32–64k | [brandonmusic](https://huggingface.co/brandonmusic/GLM-5.3-Flash-tr3-4bpw) | Not stock vLLM |
| 47–69 | 2–4× DGX Spark | vLLM DFlash2 | NVFP4 | DFlash2 k=7 | 262k–1M | tonyd2wild / cfontes | Wrong hardware class for Runpod |

LocalMaxxing has **15** approved 2× RTX PRO 6000 runs for this model. Everything above ~300 tok/s is the SGLang+DFLASH2 family. vLLM on the same 2× card sits ~150–190.

## What actually moves tok/s

Ranked. Do these in order.

1. **Right GPU generation.** Hopper (H100/H200) wants **native FP8**. Blackwell workstation (RTX PRO 6000, SM120) wants **NVFP4 + flashinfer_cutlass** (not CuteDSL — CuteDSL hard-codes sm100). Ampere is a non-starter.
2. **Speculative decoding.** DFLASH2 (block diffusion, `incoai/GLM-5.3-Flash-DFlash2`) is the only stack that has broken 300+ tok/s on this model. NEXTN/MTP is the reliable ~1.3–2× (163→211, or 143→208). No spec = ~160.
3. **Tensor parallel width vs interconnect.** 2× 96 GB is enough for NVFP4 (~180–190 GiB weights + KV). 4× helps KV/context and some MTP setups; it does not automatically 2× decode. The ceiling run is TP=2.
4. **SM120 kernel flags** ([sglang#37105](https://github.com/sgl-project/sglang/issues/37105)). Without these, SGLang dies on RTX PRO 6000:
   - `SGLANG_OPT_DEEPGEMM_HC_PRENORM=0`
   - `--dsa-prefill-backend tilelang --dsa-decode-backend tilelang`
   - `--kv-cache-dtype bfloat16` until FP8 KV is verified on sm_120
   - tilelang v1 tile retune `(block_I, stages, threads) = 32, 1, 128` if shared-mem errors
   - `--moe-runner-backend flashinfer_cutlass` (not `flashinfer_cutedsl`, not `deep_gemm` on sm_120)
5. **Reasoning effort.** Default/max thinks longer (more tokens, looks slower on "useful" tok/s). 0xSero: 143 low vs 208 default — default can be *faster decode* because MTP acceptance is higher. dealignai CRACK also needs **off or max** for full uncensor. Do not set `low` just to go faster if you care about refusals.
6. **Load path.** Presharded / local NVMe beats HF cache on first boot. On Runpod: High-Performance network volume in the same DC. You will not get the ceiling run's locked clocks or staged PCIe tricks.

## What will not work on Runpod

- Clock locks (3090/14 GHz/450 W)
- Kernel TUN / privileged Docker (`--ipc=host` may work; `/dev/net/tun` will not)
- Assuming CuteDSL / TRT-LLM DSA auto-select (sm_120 ≠ sm_100)
- Official `vllm/vllm-openai:glm53-flash` on SM120 without the sparse-MLA patch ([vllm#53963](https://github.com/vllm-project/vllm/issues/53963))
- Chasing 1004 tok/s as an acceptance test

## Runpod-realistic recipes

### Speed track — SGLang on 2× or 4× RTX PRO 6000

Image: `lmsysorg/sglang:glm-5.3-flash` (pin a digest; 0xSero used `sha256:3a97bd50034ca60c6e6c86b8e36a73675d261f6a5eb71197796aee5175409290`).

Weights: `dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4` (pin this id; ABLITERATED twin may lag). Draft: `incoai/GLM-5.3-Flash-DFlash2` (**CC BY-NC-ND**; pin commit `7d74cdd` — later Hub weights lost ~6% prose).

Start DFLASH at **native block 8**. Widen 8 → 12 → 20 only after a real completion. Do not start at 64.

```bash
export SGLANG_OPT_DEEPGEMM_HC_PRENORM=0
export SGLANG_ENABLE_JIT_DEEPGEMM=0
export HF_HUB_DISABLE_TELEMETRY=1
export NCCL_IB_DISABLE=1
python3 -m sglang.launch_server \
  --model-path /workspace/models/GLM-5.3-Flash-UNCENSORED-NVFP4 \
  --served-model-name glm-5.3-flash \
  --host 127.0.0.1 --port 8000 \
  --api-key "$GLM_API_KEY" \
  --tp-size 2 \
  --quantization modelopt_fp4 \
  --attention-backend dsa \
  --dsa-prefill-backend tilelang \
  --dsa-decode-backend tilelang \
  --moe-runner-backend flashinfer_cutlass \
  --kv-cache-dtype bfloat16 \
  --disable-shared-experts-fusion \
  --reasoning-parser glm45 \
  --tool-call-parser glm47 \
  --speculative-algorithm DFLASH \
  --speculative-draft-model-path /workspace/models/GLM-5.3-Flash-DFlash2 \
  --speculative-num-draft-tokens 8 \
  --speculative-draft-window-size 2048 \
  --max-total-tokens 65536 \
  --trust-remote-code
```

If DFLASH2 fails to boot (image may lack [sglang#36708](https://github.com/sgl-project/sglang/pull/36708)): use NEXTN/MTP — 0xSero’s 143/208 path (`NEXTN`, 5 steps, 6 draft tokens). Their `flashinfer_sparse_mla` + FP8 KV only works with six baked patches; on stock image keep TileLang + bf16 KV.

Do **not** serve this NVFP4 on vLLM on SM120 — [vllm#54150](https://github.com/vllm-project/vllm/issues/54150) ModelOpt U+FFFD corruption. SGLang is the speed-track engine.

### Fallback — vLLM on 4× H200

Image: `vllm/vllm-openai:glm53-flash`. Weights: `dealignai/GLM-5.3-Flash-UNCENSORED-FP8`.

```bash
vllm serve /workspace/models/GLM-5.3-Flash-UNCENSORED-FP8 \
  --host 127.0.0.1 --port 8000 \
  --tensor-parallel-size 4 \
  --tool-call-parser glm47 --reasoning-parser glm45 --enable-auto-tool-choice \
  --speculative-config '{"method":"mtp","num_speculative_tokens":1}'
```

Expect ~160–210 tok/s single stream. Hopper does **not** support FP8 KV for this model (vLLM recipe). FlashInfer ≥ 0.6.18.

## Honest target for this project

| Label | tok/s | Meaning |
| --- | ---: | --- |
| Floor | 150–190 | vLLM on 2× RTX PRO 6000 if SGLang will not boot |
| Good | 200–270 | NEXTN/MTP (0xSero 208; rtx6kpro MTP3 267 on 4×) |
| Great | **300–391** | DFLASH2 k=8 on real prompts, no clock lock (their own steady-state) |
| Inflated | 443–514 | Same stack, **best-of-N** |
| Ceiling | 808–1004 | n-gram / attractor / clock lock — do not claim |
