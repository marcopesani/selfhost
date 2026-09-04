# Source index

Collected 2026-09-02. Prefer these over memory.

## Context (200k / 1M)

- Native window: `max_position_embeddings` 1048576 in `zai-org/GLM-5.3-Flash` config.json
- Writeup: [`context.md`](context.md)
- 0xSero 4× / 1M / NVFP4: <https://github.com/0xSero/glm-5.3-flash-sglang-sm120>
- rtx6kpro 4× / 262k (200k class): <https://github.com/local-inference-lab/rtx6kpro/blob/master/models/glm-5.3-flash.md>
- vLLM TP=2 ~185k fp8 pool: <https://github.com/vllm-project/vllm/issues/53963>
- samuelcardillo 2× EXL3 1M (not our checkpoint): <https://github.com/samuelcardillo/glm-5.3-flash-2x-rtx-pro-6000-blackwell>

## Speed

- LocalMaxxing model + ceiling run: <https://www.localmaxxing.com/en/models/zai-org/GLM-5.3-Flash?run=cmtk0maew03mrp701oyaivvka>
- LocalMaxxing API: `GET https://www.localmaxxing.com/api/speed-tests?hfId=zai-org/GLM-5.3-Flash&limit=100`
- Snapshots: `refs/snapshots/localmaxxing-cmtk0maew03mrp701oyaivvka.json`, `refs/snapshots/localmaxxing-glm-5.3-flash-runs.json`
- vLLM recipe: <https://recipes.vllm.ai/zai-org/GLM-5.3-Flash>
- 0xSero SGLang SM120 bundle: <https://github.com/0xSero/glm-5.3-flash-sglang-sm120>
- SGLang sm_120 DSA blockers (working flags): <https://github.com/sgl-project/sglang/issues/37105>
- vLLM SM120 sparse-MLA: <https://github.com/vllm-project/vllm/issues/53963>
- DFlash2 draft: <https://huggingface.co/incoai/GLM-5.3-Flash-DFlash2>
- tonyd2wild Spark DFlash2: <https://github.com/tonyd2wild/GLM-5.3-Flash-NVFP4-DFlash2-2x-DGX-Spark>
- local-inference-lab 4× PRO 6000: <https://github.com/local-inference-lab/rtx6kpro/blob/master/models/glm-5.3-flash.md>
- brandonmusic EXL3 TR3: <https://huggingface.co/brandonmusic/GLM-5.3-Flash-tr3-4bpw>
- TreeRouter deploy guide: <https://api.treerouter.ai/en/blog/glm-5-3-flash-deployment-guide>

## Abliterated

- dealignai CRACK FP8: <https://huggingface.co/dealignai/GLM-5.3-Flash-ABLITERATED-FP8>
- dealignai CRACK NVFP4 **(pin this)**: <https://huggingface.co/dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4>
- dealignai CRACK NVFP4 twin (do not mix commits): <https://huggingface.co/dealignai/GLM-5.3-Flash-ABLITERATED-NVFP4>
- vLLM ModelOpt U+FFFD on SM120: <https://github.com/vllm-project/vllm/issues/54150>
- SGLang DFLASH PR: <https://github.com/sgl-project/sglang/pull/36708>
- dealignai UNCENSORED mirrors (same tensors): `-UNCENSORED-FP8`, `-UNCENSORED-NVFP4`
- rbinrs NVFP4 (stale, do not download): <https://huggingface.co/rbinrs/GLM-5.3-Flash-ABLITERATED-NVFP4>
- orcarouter FP8 (gated, residual refusal): <https://huggingface.co/orcarouter/GLM-5.3-Flash-Uncensored-FP8>
- orcarouter NVFP4: <https://huggingface.co/orcarouter/GLM-5.3-Flash-Uncensored-NVFP4>
- Independent writeup of orcarouter: <https://apidog.com/blog/glm-5-3-flash-uncensored/>
- Blackfrost DERISKED NVFP4: <https://huggingface.co/Blackfrost-AI/GLM-5.3-Flash-DERISKED-NVFP4>
- drowzeys keys splice: <https://huggingface.co/drowzeys/keys-GLM-5.3-Flash-NVFP4-ablit-l15-45-anchorstock>
- NOT Flash (753B): <https://huggingface.co/dealignai/GLM-5.3-ABLITERATED-NVFP4>
- NOT Flash (753B cybersecurity CRACK, 8× H200 recipe): <https://huggingface.co/dealignai/GLM-5.3-CYBERSECURITY-FP8>
- NOT Flash (753B NVFP4 size: ~433 GiB, 4× 96 GB does not fit): <https://huggingface.co/LibertAIDAI/GLM-5.3-NVFP4>
- Heretic GGUF LoRA (abliteration only, 26% residual): <https://huggingface.co/MorinoNushi/GLM-5.3-Flash-Heretic-LoRA-V1-GGUF>
- GLM-4.7-Flash cyber LoRA (wrong base): <https://huggingface.co/neilopet/glm4-cybersec-v2-lora>
- Flash GLP-44 (gated steering, not LoRA): <https://huggingface.co/msuiche/GLM-5.3-Flash-abliterated-cyber-GLP-44>
- mHC vs LoRA (lovesenko TR3 card): <https://huggingface.co/lovesenko/GLM-5.3-Flash-tr3-4bpw-Abliterated>
- SGLang experimental NVFP4 MoE LoRA: <https://github.com/sgl-project/sglang/pull/27329>

## Red-team research (this 4× / 1M pod)

- Writeup: [`red-team.md`](red-team.md)
- Z.ai GLM-5.3 (CyberGym / ExploitBench are **753B**): <https://z.ai/blog/glm-5.3>
- Z.ai GLM-5.3-Flash (no CyberGym row; Toolathlon 78.4): <https://z.ai/blog/glm-5.3-flash>
- Graphistry CyBT-CTF (GLM-5.2; harness > model): <https://www.graphistry.com/blog/glm-5-2-cybersecurity-open-model>
- TrustedSec self-host offsec (workstation-size models): <https://trustedsec.com/blog/benchmarking-self-hosted-llms-for-offensive-security>
- llm-stats Flash vs 5.3: <https://llm-stats.com/models/compare/glm-5.3-vs-glm-5.3-flash>
- pi default tools: <https://github.com/earendil-works/pi/blob/main/packages/coding-agent/README.md>
- pi models.json: <https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models.md>
- XPI (casefile / webxp / `/xp`): <https://github.com/xaccefy/pi-xpi>
- XPI guide: <https://github.com/xaccefy/pi-xpi/blob/main/docs/guide.md>
- OpenCode providers (laptop A/B only): <https://opencode.ai/docs/providers/>

## In-pod devops

- Writeup: [`ops.md`](ops.md)
- SGLang `/health` orphan bug (do not loop it): <https://github.com/sgl-project/sglang/issues/35884>
- VictoriaMetrics query API: <https://docs.victoriametrics.com/victoriametrics/single-server-victoriametrics/>
- pi prompt templates: <https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/prompt-templates.md>
- pi-debug-dashboard (rejected HTTP): <https://github.com/ricoyudog/pi-debug-dashboard>
- Optional local pi-telemetry SQLite: <https://www.npmjs.com/package/@spences10/pi-telemetry>

## Reseller pricing

- Writeup: [`pricing.md`](pricing.md)
- Our in-band rows: [`benchmark.md`](benchmark.md)
- Pod dollars: [`../runpod/cost.md`](../runpod/cost.md)
- Runpod storage (volume disk $0.10/GB-month running, $0.20 stopped): <https://docs.runpod.io/pods/storage/types>
- Z.ai / OpenRouter GLM-5.3-Flash catalog (comp only, not our list): <https://openrouter.ai/z-ai/glm-5.3-flash>
- Z.ai list vs promo writeup: <https://codersera.com/blog/glm-5-3-flash-complete-guide-2026/>

## Privacy / Runpod / Tailscale / confidential computing

- Runpod security: <https://docs.runpod.io/references/security-and-compliance>
- Runpod storage (encrypted volume disk, no BYOK, network-volume limit): <https://docs.runpod.io/pods/storage/types#encrypted-volumes>
- Runpod data-security guide (broad platform encryption claim): <https://www.runpod.io/articles/guides/keep-data-secure-cloud-gpus>
- Runpod expose ports / proxy: <https://docs.runpod.io/pods/configuration/expose-ports>
- Runpod global networking: <https://docs.runpod.io/pods/networking>
- NVIDIA confidential-computing reference (RTX PRO 6000 BSE validation): <https://docs.nvidia.com/enterprise-reference-architectures/deploying-proprietary-models-confidential-compute-self-hosted-vms/latest/reference-implementations.html>
- NVIDIA confidential-computing required capabilities: <https://docs.nvidia.com/enterprise-reference-architectures/deploying-proprietary-models-confidential-compute-self-hosted-vms/latest/required-capabilities.html>
- NVIDIA attestation and key-release flow: <https://docs.nvidia.com/enterprise-reference-architectures/deploying-proprietary-models-confidential-compute-self-hosted-vms/latest/attestation-and-key-release-flow.html>
- No TUN / NET_ADMIN: <https://github.com/runpod/runpodctl/issues/272>
- Discord archive (Tailscale on pod): <https://www.answeroverflow.com/m/1232985784189976667>
- Userspace Tailscale: <https://tailscale.com/kb/1112/userspace-networking>
- Userspace inbound rewrite (localhost hazard): <https://github.com/tailscale/tailscale/issues/10267>
- Community Runpod Tailscale recipe: <https://github.com/koshimazaki/tailscale-runpod>
