# Red-team research setup on this pod

Researched 2026-09-04. Question: what is the best setup *on the already-chosen
4× RTX PRO 6000 / 1M box* for authorized offensive-security *research*
(source review, vuln discovery, long-horizon agent loops) — not a new SKU.

## Verdict

Keep **`dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4`** (ADR-010) at
`--context-length 1048576` (ADR-018). Spend the first live sitting on the
**research harness** (ADR-019), not on swapping weights.

CyberGym **84.5%** is **GLM-5.3 753B**, vendor-reported. Flash has **no**
published CyberGym / ExploitBench. That 753B NVFP4 is ~433 GiB; this pod is
384 GB. The cybersecurity CRACK
(`dealignai/GLM-5.3-CYBERSECURITY-FP8`) is the same 753B family on **8× H200**
at `max-model-len 131072` in their card — a different product.

## Why Flash is the research model that fits

| Need | Flash UNCENSORED on 4× | 753B GLM-5.3 | Small cyber fine-tunes |
| --- | --- | --- | --- |
| Fits 384 GB at 1M | Yes (~244 GB boot est.) | No (~433 GiB NVFP4 weights) | Yes, wasted VRAM |
| Native 1M | Yes | Yes, but not on this SKU | Qwen Flash-Next 262k + YaRN |
| Refusal on security research | HarmBench-320 **0%** at off/max | Separate CRACK; doesn't fit | Fine-tune dependent |
| Agent tool-use (Toolathlon) | **78.4** | 73.0 | Not in the same table |
| Vision (screenshots / diagrams) | Native tower retained | Text-only | Usually no |
| In-band decode at 1M configured | 208 tok/s MTP (0xSero) | N/A here | Fast and weak |

Flash is not a distilled 753B. It is a 320B/18B hybrid (KDA + sparse MLA)
trained for cheap 1M agents. On the one agent bench both sizes publish,
**Flash beats 753B**.

## Flash-tier numbers (models that can share this GPU class)

Z.ai GLM-5.3-Flash launch table, 2026-08-26. Harnesses are not identical
across labs.

| Bench | GLM-5.3-Flash | DeepSeek V4 flash-class | Opus 4.8 |
| --- | ---: | ---: | ---: |
| Terminal Bench 2.1 | 84.3 | 82.7 (DataCamp) / 83.9 (V4-Vision-Exp) | 85.0 |
| DeepSWE v1.1 | 63.4 | 59.3 | 58.0 |
| Toolathlon Verified | 78.4 | 75.9 | 76.2 |
| Agents' Last Exam | 26.3 | 27.3 | 27.0 |

Do **not** switch to V4 Flash on this template: stock alignment still
refuses, there is no CRACK in our catalog, and the SGLang SM120 recipe is
the Flash one we already pinned.

Qwen3.8 Flash-Next: 262,144 native. YaRN to 1M is off by default because it
hurts short-context quality. Wrong long-ctx product.

Chimera / RavenX-style **35B-A3B** cyber LoRAs: workstation models. TrustedSec's
self-host SQLi set (gemma4 98.5%, qwen3.5 97.5%) is the same size class —
single-step payload challenges, not 1M repo agents.

## 753B cyber numbers (different SKU)

Z.ai GLM-5.3 blog, 2026-08-14. Claude Code 2.1.207, no web tools,
vendor-reported.

| Bench | GLM-5.3 | Mythos 5 | GPT-5.6 Sol |
| --- | ---: | ---: | ---: |
| CyberGym | 84.5% | 83.8% | 83.6% |
| ExploitBench | 54.4% | 78.0% | 76.5% |
| ExploitGym 2h / 6h | 105 / 130 | 181 / 247 | 216 / 293 |

Their own reading: discovery is near-frontier; further up the exploit chain
the closed models pull away. Independent Graphistry CyBT-CTF (GLM-**5.2** era):
OpenCode+GLM 28/59 vs Louie+Opus 35/59 — **harness moved the score more than
the model**.

If CyberGym-class 753B is required later: new ADR, **8× RTX PRO 6000** or
**8× H200**, not this template. EXL3 ~3 bpw on 4× abandons the SGLang 1M
speed track and is rejected for this pod.

## Flash checkpoint families (unchanged)

See [`abliterated.md`](abliterated.md). For this workload the pin is still
UNCENSORED-NVFP4 at `reasoning_effort=max`. There is no Flash-specific
cybersecurity CRACK. `msuiche/GLM-5.3-Flash-abliterated-cyber-GLP-44` is a
gated **steering vector**, not a LoRA.

## LoRA — do not apply one (ADR-020)

Question (2026-09-04): can / should a LoRA be attached to the pinned NVFP4
CRACK to improve red-team research?

**No.** There is nothing to load, and the architecture fights the ones that
exist.

HF catalog the same day: **0** PEFT adapters on `zai-org/GLM-5.3-Flash`
(`filter=adapter` and `filter=peft` both empty). What showed up instead:

| Artifact | What it actually is | Load on this pod? |
| --- | --- | --- |
| `MorinoNushi/GLM-5.3-Flash-Heretic-LoRA-V1-GGUF` | Rank-1 Heretic abliteration for **llama.cpp**. Trial 8, study unfinished. Harmful refusal **26.4%** (37/140), KL 0.068 vs UD-IQ4_XS. | No — wrong engine; worse uncensor than CRACK 0% |
| `neilopet/glm4-cybersec-v2-lora` | Cyber SFT LoRA on **GLM-4.7-Flash** (30B DeepSeek2 MoE, heretic base) | No — different model |
| xOffense LoRA | Qwen3-**32B** + PentestData / WhiteRabbitNeo | No — different model |
| Chimera / RavenX 35B-A3B | Qwen3.6 cyber fine-tunes, not Flash adapters | No — different model |
| `msuiche/GLM-5.3-Flash-abliterated-cyber-GLP-44` | Gated **GLP control vector** (steering), not LoRA. 22 downloads. | No — don’t mix with CRACK |
| `HollowMan6/GLM-5-NOOP-LoRA` | Empty init for **GLM-5** (not Flash) | No |
| dealignai / orcarouter / Blackfrost | Full-weight edits, explicitly **not LoRA** | Already decided (ADR-010) |

Why a future Flash-native cyber LoRA still would not be the default here:

1. **mHC.** GLM-5.3-Flash residual path re-normalizes low-rank perturbations. The lovesenko TR3 abliteration card states LoRA-style edits produce near-zero behavioral change; they edit `o_proj` in the 4096-d residual instead. dealignai CRACK is the same class of weight-level `o_proj` edit. Abliteration-via-LoRA is the thing this arch is built to resist.
2. **Serve stack.** Config B is SM120 TileLang + `flashinfer_cutlass`. SGLang’s NVFP4 MoE LoRA path is opt-in (`SGLANG_EXPERIMENTAL_LORA_OPTI`) and documented against `--moe-runner-backend experimental_sgl_trtllm` — the SM120 TRT-LLM footgun. Published LoRA-on-NVFP4 MoE (Qwen3.5-35B-A3B / Kimi-K2.5) recover ~65% of no-LoRA tok/s. `--enable-lora` also disables piecewise CUDA graph / NVFP4 SwiGLU fusion.
3. **Spec.** DFLASH2 and the cracked MTP head are calibrated to the unadapted target. Adapter on the target without a matching draft is how spec acceptance dies — the same reason dealignai cracked the MTP head with the body.
4. **Train-our-own.** BF16 Flash is ~650 GB. Occupying the $8.36/hr 4× box to QLoRA, then merge/requant, produces a new digest that is not ADR-010. No published Flash cyber corpus at 1M-agent quality exists to justify that.

Domain knowledge for this workload is the **harness** (ADR-019): offline CWE / ATT&CK / NVD + semgrep + 1M ingest. That is cheaper and does not fight mHC.

## Harness (the actual upgrade)

Local operator copy: `configs/research-harness.md` (gitignored).
Bindings: ADR-019, ADR-021.

This pod is the private brain: model + pi + a **local-only XPI slice** +
offline knowledge. It is **not** a scanner distro. Network-offensive tooling
for authorized labs stays on a machine the operator already controls, not
beside weights, prompts, and `GLM_API_KEY`.

### What exists that is actually specialized

There is one open package built *for* the agent we already picked
(`@earendil-works/pi-coding-agent`): **XPI** (`@xaccefy/pi-xpi`, MIT, 2026).
Casefile with enforced gates, skeptic stage, coverage matrix, exploit-chain
suggest, structural `ast_grep`. `/xp lite` is the single-agent security
workflow; `/xp swarm` dispatches auditor / tracer / skeptic / chain.

The umbrella also ships **webxp**: `web_search`, `web_fetch`, Context7,
DeepWiki, and `exploit_search` → preview.is (`PREVIEW_IS_API_KEY`). That is
incompatible with `PI_OFFLINE=1` and with prompts that must not leave the
guest. Install **casefile + xtodo only**. Do not set `PREVIEW_IS_API_KEY`.
Default **`/xp lite`**, not swarm, on this 4× / 1M SKU.

That *is* the specific pi configuration. models.json stays ADR-015
(`baseUrl http://127.0.0.1:8000/v1`, `served-model-name glm-5.3-flash`,
`contextWindow 1048576`, `compat.supportsDeveloperRole: false`,
`reasoning: true`, `PI_OFFLINE=1`). Extra env: `PI_XP_MODE=lite`,
`PI_CASEFILE_PATH=/workspace/findings/casefile.db`.

### Open pentest agents — keep off this guest

| Harness | License / hook | Fit |
| --- | --- | --- |
| **XPI casefile + xtodo** on earendil pi | MIT; `pi install npm:@xaccefy/pi-casefile` | **Yes** — native to ADR-015 |
| Full `@xaccefy/pi-xpi` / `pi-webxp` | MIT; preview.is + open-websearch | No — queries leave the pod |
| `soulofzephir/pi-skill-pentesting` | OWASP / header-scan skill | No — scanner-shaped on the inference box |
| `omp-cyberstrike` | OMP fork, 143 web-pentest skills | No — replaces earendil pi |
| **OpenCode** | Apache-2.0; OpenAI-compat `baseURL` | Optional **laptop** A/B (Graphistry CyBT used it with GLM). Not in-pod primary. Custom-provider bugs exist (`options` sometimes dropped). |
| CAI (`aliasrobotics/cai`) | LiteLLM, Phoenix tracing, `OPENAI_BASE_URL` | Lab machine only. Adapter + recon tools + traces violate ADR-015 / 019 |
| Strix / PentAGI / T3MP3ST / Decepticon | Autonomous pentest, Kali, arsenal | Separate lab host. Not this image |
| PentestGPT | Autonomous path = Claude Code / Codex | Methodology notes, not the 1M repo loop |
| Louie (Graphistry) | Proprietary Hub | Not open; CyBT’s *best* harness, not ours |

Graphistry’s own reading still holds: harness moved CyBT more than GLM vs
Opus. The open lever we can actually run privately is **pi + casefile lite**,
not Louie and not a Kali sidecar next to the weights.

## Sources

- Z.ai GLM-5.3: https://z.ai/blog/glm-5.3
- Z.ai GLM-5.3-Flash: https://z.ai/blog/glm-5.3-flash
- dealignai Flash UNCENSORED-NVFP4 (HF card, HarmBench table)
- dealignai GLM-5.3-CYBERSECURITY-FP8 (753B, 8× H200 recipe)
- LibertAIDAI GLM-5.3-NVFP4 (433 GiB; 4× 96 GB does not fit)
- Graphistry CyBT-CTF / GLM-5.2: https://www.graphistry.com/blog/glm-5-2-cybersecurity-open-model
- TrustedSec self-host offsec benches: https://trustedsec.com/blog/benchmarking-self-hosted-llms-for-offensive-security
- llm-stats Flash vs 5.3 (2026-09-04 fetch)
- Local AI Zone flash-tier survey (architecture / context)
- pi default tools: earendil-works/pi coding-agent README (`read` `write` `edit` `bash`)
- Heretic GGUF LoRA (abliteration, 26% residual, not cyber): https://huggingface.co/MorinoNushi/GLM-5.3-Flash-Heretic-LoRA-V1-GGUF
- GLM-4.7-Flash cyber LoRA (wrong base): https://huggingface.co/neilopet/glm4-cybersec-v2-lora
- xOffense (Qwen3-32B LoRA): https://arxiv.org/pdf/2509.13021
- lovesenko TR3 card (mHC vs LoRA): https://huggingface.co/lovesenko/GLM-5.3-Flash-tr3-4bpw-Abliterated
- SGLang experimental NVFP4 MoE LoRA: https://github.com/sgl-project/sglang/pull/27329
- Flash GLP-44 (steering, gated): https://huggingface.co/msuiche/GLM-5.3-Flash-abliterated-cyber-GLP-44
- XPI (pi security tools): https://github.com/xaccefy/pi-xpi
- XPI guide (webxp / PREVIEW_IS / `/xp lite`): https://github.com/xaccefy/pi-xpi/blob/main/docs/guide.md
- pi models.json: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models.md
- OpenCode custom OpenAI-compat provider: https://opencode.ai/docs/providers/
