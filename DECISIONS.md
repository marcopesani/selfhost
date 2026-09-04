# Decisions

Append-only. Newest first. Reverse a decision by adding a new ADR that supersedes the old one.

## ADR-026 — Reseller list is GPU-second cost + 20% on this boot’s measured rates

**Date:** 2026-09-04
**Status:** accepted
**Qualifies:** ADR-007 (208 / 1004 are not the SLA), ADR-010 (CRACK, `reasoning_effort=max`), ADR-016 (provider-trusted), ADR-019 (one research stream), ADR-023 (consumer decode), ADR-025 (512k window)

Resale of access to **this** serve is priced from **our** in-band GPU-seconds, not from Z.ai / OpenRouter GLM-5.3-Flash ($0.15 / $0.50 / $0.03 list) and not from 0xSero’s 208 tok/s MTP number. This image has no MTP (sglang#36599). DFLASH2 is CC BY-NC-ND — do not use it to cut the output price.

**Busy-GPU list** (20% over fully-loaded $8.42/hr, rounded up):

| Meter | List / MTok |
| --- | ---: |
| Input (cache miss) | **$0.35** |
| Cached input | **$0.038** |
| Output (incl. thinking) | **$47** |

Rates behind the list: prefill **8,087 tok/s**, cache floor **75,000 tok/s**, decode **60.0 tok/s** (ADR-023 94k briefing). Thinking tokens are output. One 512k stream.

Same 20% as a reserved seat: **$10.10/hr**. A shared always-on API that is not full uses the 70% occupancy list in [`refs/pricing.md`](refs/pricing.md) ($0.50 / $0.054 / $67). Do not match Z.ai on $/MTok — the product is uncensored 512k on a dedicated box.

Rewrite this ADR if MTP serves, DFLASH is licensed for commercial use, or the GPU/storage rate changes. Math and worked checks: [`refs/pricing.md`](refs/pricing.md).

## ADR-025 — This boot’s API max context is 512k, so usage can hit 100%

**Date:** 2026-09-04
**Status:** accepted
**Supersedes:** ADR-024 (client-only 256k cap with a 1M pool)
**Qualifies:** ADR-013 (200k or 1M menu), ADR-018 (config B was 1M native)

The OpenAI/Anthropic/pi usage bar is `used / context_length`. Serving `--context-length 1048576` while the DSA indexer CUDA-OOMs at ~655k–825k means the bar never fills — the process dies first. That is dishonest UX.

This 4× boot therefore **serves 512k**:

- `--context-length 524288`
- `--max-total-tokens 524288`
- pi `contextWindow: 524288` (same file on laptop and pod)
- Fill chunks stay 16384. Omit-cap stays 65536 (ADR-023).

512×1024 = 524288 (divides 64/256 page sizes). It is above the 200k class, below the measured indexer cliff, and is the number a client should treat as **full**. Do not keep a 1M KV slab “just in case.” Do not advertise 1M. Do not use 256k as the API window.

A later image that holds a 1M chat without dying may restore ADR-018’s 1048576 with a new ADR.

## ADR-024 — Live chats and soaks cap at 256k on this boot; the pool stays 1M

**Date:** 2026-09-04
**Status:** superseded by ADR-025
**Qualifies:** ADR-013 (serve 200k or 1M), ADR-018 (config B 1M pool)

Misread. The 256k figure was a soak cap with the 1M pool left in place. Wrong lever: usage UX follows the API `context_length`, not a client-only budget. Keep as history.

## ADR-023 — Consumer decode defaults: 65k omit-cap, reserve 16k for content, larger prefill

**Date:** 2026-09-04
**Status:** accepted
**Qualifies:** ADR-015 (OpenAI/Anthropic wire, pi primary)

Daily jobs on this serve must feel like ChatGPT/Claude, not a 1024-token bench. GLM-5.3 always thinks first; `glm45` keeps `content` empty until the think-end tag; thinking counts against `max_tokens`.

Defaults:

- Omitted `max_tokens` / `max_completion_tokens` → **65536**, not SamplingParams' 128 and not until-EOS / leftover 1M context.
- Auto thinking budget = `max(0, max_new_tokens − 16384)` unless the client sets `custom_params.thinking_budget`. Pass `-1` to uncap think (still bounded by `max_tokens`).
- Processor is `Glm53FlashThinkingBudgetLogitProcessor` (ids **154841/154842**). Do not use `Glm4MoeThinkingBudgetLogitProcessor` (4.5 ids).
- `--max-prefill-tokens 131072`, `--chunked-prefill-size 16384`.
- `--preferred-sampling-params '{"max_new_tokens":65536}'` as belt-and-suspenders.
- `--enable-custom-logit-processor` (loopback + bearer is the trust boundary).
- `--stream-response-default-include-usage`.
- Do **not** `--allow-auto-truncate`. Do **not** default `reasoning_effort=low`. Do **not** send `enable_thinking=false`.

Clients (pi): `maxTokens` 65536, `stream` true, `reasoning_effort=max`, read timeout ≥ 20 min. Explicit tiny `max_tokens` still wins — benches may clip.

## ADR-022 — In-pod devops is a dumb snapshot plus a short pi ops skill, not another dashboard

**Date:** 2026-09-04
**Status:** accepted
**Qualifies:** ADR-015 (vmui-only observability, pi primary)

The pod must still diagnose itself when SGLang is **down**. That rules out any LLM-only ops agent as the primary harness. Two layers:

1. **Dumb (always on).** `configs/ops-snapshot.sh` on a 60s loop writes `/workspace/ops/LATEST.md` (and `.json`) from `nvidia-smi`, `df`, listen-on-8000, process list, download tail. No `/health` loop (sglang#35884 orphans generation health checks). No `/get_server_info` (CVE-2026-15977). No ingest of `sglang.log` (startup line prints the API key).
2. **LLM (only when the API is up).** A separate tmux window running the same earendil pi, skill `pod-ops`, prompt `/ops`. Short prompts. It reads `LATEST.md`, curls `http://127.0.0.1:8428/api/v1/query` and `http://127.0.0.1:8000/metrics`, writes `/workspace/ops/reports/`. It does **not** share the research XPI session and does not `/xp swarm`.

**Report to human** is files on the encrypted volume + SSH, not chat SaaS:

- `ssh … cat /workspace/ops/LATEST.md` (works when the model is dead)
- optional login banner / tmux status pointing at that file
- narrative reports under `/workspace/ops/reports/` when pi is up

Do not Slack, email, Discord, Datadog, Langfuse, Phoenix, or any webhook from this guest.

**Self-heal:** snapshot and diagnose are on by default. **Auto-restart of SGLang is off** unless `/workspace/ops/AUTO_RESTART` exists. A 4× cold boot is many minutes and $8.36/hr; a restart loop is a billable footgun. Restarting SGLang also kills the in-pod pi mid-turn. Exporters/vmui may be restarted by the ops skill; SGLang restart is human (or the flag file).

Do **not** install HTTP ops UIs on this guest: Grafana (already ADR-015), `pi-debug-dashboard` (:9848), `pi-hub`, `disler/pi-agent-observability`, Netdata. They want browsers and extra `-L` ports. Human graphs stay vmui `:8428`. Optional local-only `@spences10/pi-telemetry` SQLite is allowed for *agent* turn stats; keep the db under `/workspace/ops/` and do not export it off-box.

Operator copy stays local (`configs/ops-harness.md`, gitignored). Catalog: [`refs/ops.md`](refs/ops.md).

## ADR-021 — Red-team harness is a local XPI slice on pi, not a pentest distro

**Date:** 2026-09-04
**Status:** accepted
**Qualifies:** ADR-015 (pi primary), ADR-019 (not a scanner image)

The specialized open red-team harness for *this* serve is **pi + a local-only XPI slice**, not a new agent.

Install on laptop and pod:

- `@xaccefy/pi-casefile` — hypothesis → investigating → confirmed ledger, two-phase PoC gates, coverage matrix, `ChainSuggest`
- `@xaccefy/pi-xtodo` — task lists that survive compaction
- `ast-grep` already on `/workspace` (ADR-019) — XPI’s `ast_grep` tool if the casefile package registers it; otherwise bash to the same binary

Run **`/xp lite`** (`PI_XP_MODE=lite`). Ledger: `PI_CASEFILE_PATH=/workspace/findings/casefile.db`. `PI_OFFLINE=1` stays.

Do **not** install the umbrella `@xaccefy/pi-xpi` or `@xaccefy/pi-webxp`. Those pull `open-websearch`, `web_search` / `web_fetch` / `context7` / `deepwiki`, and `exploit_search` against [preview.is](https://preview.is) (`PREVIEW_IS_API_KEY`). Queries and target names leave the guest. Do not set `PREVIEW_IS_API_KEY`.

Do **not** default `/xp swarm` (auditor / tracer / skeptic / chain). This SKU is one 1M stream; four subagents share the same GPUs and multiply the sglang#36669 thinking-degeneration risk. Swarm is an opt-in later, still without webxp.

Do **not** install `soulofzephir/pi-skill-pentesting` or switch the binary to `shantanu561993/omp-cyberstrike` (OMP fork, 143 web-pentest skills). Payload / header-scan shaped; would replace or overload earendil pi.

PoC network flags stay unset on the inference guest (`PI_POC_ALLOW_NETWORK`, `PI_POC_ALLOW_PRIVATE_REPLAY`). Live replay against an authorized lab belongs on a machine the operator already controls.

Rejected as the *primary* in-pod harness (they can live on a separate lab host talking through `ssh -L` if the operator wants them later):

| Harness | Why not here |
| --- | --- |
| CAI (`aliasrobotics/cai`) | LiteLLM adapter (ADR-015), Phoenix traces, ships recon/exploit tools |
| Strix, PentAGI, T3MP3ST, Decepticon | Autonomous pentest / Kali / arsenal images — scanner distro beside weights |
| PentestGPT | Autonomous path drives Claude Code / Codex; methodology, not a 1M repo agent |
| OpenCode | Graphistry’s *open* CyBT baseline with GLM; can point at `127.0.0.1:8000`. Optional laptop A/B only — not a second in-pod brain |
| Louie | Proprietary Graphistry Hub; not an open drop-in |

Operator copy stays local (`configs/research-harness.md`, gitignored). Catalog: [`refs/red-team.md`](refs/red-team.md).

## ADR-020 — Do not attach a LoRA on this Flash NVFP4 serve

**Date:** 2026-09-04
**Status:** accepted
**Qualifies:** ADR-010 (weights), ADR-004 (SGLang+NVFP4), ADR-019 (research harness)

No LoRA is loaded at boot. Do not `--enable-lora`, do not merge an adapter into the NVFP4 shards, do not train one on this pod while it is the inference box.

Catalog (HF 2026-09-04): **zero** PEFT adapters tagged for `zai-org/GLM-5.3-Flash`. The only Flash-named “LoRA” is `MorinoNushi/GLM-5.3-Flash-Heretic-LoRA-V1-GGUF` — a **rank-1 GGUF abliteration** for llama.cpp, trial 8 of an unfinished Optuna study, harmful-refusal **26.4%** vs base 95%. That is worse than the already-pinned CRACK (HarmBench-320 **0%** at max) and is the wrong engine.

Cyber LoRAs that *do* exist (`neilopet/glm4-cybersec-v2-lora` on GLM-**4.7**-Flash 30B; xOffense on **Qwen3-32B**) are different architectures. They cannot be applied to `glm5_next`.

Even a hypothetical Flash-native cyber SFT LoRA would be rejected on this SKU until measured otherwise:

- **mHC** (Manifold-Constrained Hyper-Connections) re-normalizes low-rank residual perturbations. Abliteration authors (lovesenko TR3 card; dealignai CRACK) edit `o_proj` in weight space *because LoRA-style edits produce near-zero behavioral change* on this arch.
- Our SM120 recipe is TileLang DSA + `flashinfer_cutlass`. SGLang’s NVFP4 MoE LoRA path is experimental and wants `--moe-runner-backend experimental_sgl_trtllm` — the SM120 TRT-LLM footgun (sglang#37105). Published LoRA-on-NVFP4 MoE recover ~65% of no-LoRA throughput.
- DFLASH2 / cracked MTP are calibrated to the unadapted target. An adapter on the target without a matching draft collapses spec.
- Training our own would need the BF16 (~650 GB) or a QLoRA path, occupy the billable 4× box, then a merge/requant that is not the pinned digest.

`msuiche/GLM-5.3-Flash-abliterated-cyber-GLP-44` is a **GLP control vector**, not a LoRA; gated; 22 downloads. Same class of “don’t mix with CRACK” as the 753B GLP-77.

The research upgrade stays ADR-019 (harness), not an adapter.

## ADR-019 — This 4× pod is a Flash research agent, not a 753B cyber box or a scanner distro

**Date:** 2026-09-04
**Status:** accepted
**Qualifies:** ADR-010 (weights), ADR-015 (pi), ADR-018 (config B)

Workload on this pod is authorized security *research*: whole-repo review, vuln discovery from source, long-horizon agent loops. The best setup **on this SKU** is still **`dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4`** at 1M. Do not swap the primary checkpoint for GLM-5.3 753B, for `dealignai/GLM-5.3-CYBERSECURITY-FP8`, for DeepSeek V4 Flash, or for 35B cyber LoRAs.

Reasons that are not going to change without a new SKU or a new measurement:

- CyberGym 84.5% / ExploitBench 54.4% are **753B**, vendor-reported. Flash has no published CyberGym. 753B NVFP4 is ~433 GiB; 4× 96 GB is 384 GB. The cybersecurity CRACK’s published recipe is 8× H200 @ 131k.
- Flash Toolathlon **78.4** vs 753B **73.0**. This box is the better published tool-caller of the two GLM-5.3 sizes, and it keeps vision.
- Graphistry CyBT-CTF (GLM-5.2): harness moved the score more than GLM vs Opus. The upgrade on *this* pod is the harness.

Harness bindings (local operator copy `configs/research-harness.md`, gitignored):

- pi (ADR-015) with `read` / `write` / `edit` / `bash` only as native tools. Extra capability is local CLIs on `/workspace` (git, ripgrep, fd, ast-grep, jq, sqlite3, uv, semgrep) plus an offline KB (`CWE` / ATT&CK STIX / optional NVD JSON).
- No cloud MCP. No Cursor. No HTTP ports.
- This image is **not** a scanner / C2 distro. Network-offensive tooling for authorized labs stays on a machine the operator already controls — not beside weights, prompts, and `GLM_API_KEY`.
- `reasoning_effort=max`. Temperature ≥ ~1 for tool calls. First-sitting smoke includes a multi-tool pi session (sglang#36669) and a long in-band ingest.

If CyberGym-class 753B is required later: write a new ADR and provision **8× RTX PRO 6000** or **8× H200**. EXL3 ~3 bpw of 753B on 4× is rejected here — it abandons the SGLang 1M speed track.

## ADR-018 — Config B is binding: 1M native window on 4× RTX PRO 6000

**Date:** 2026-09-04
**Status:** accepted
**Supersedes:** the "default if unspecified" escape in ADR-013

The A-or-B choice from ADR-013 is now **B**: `--context-length 1048576`, **4× RTX PRO 6000**, bf16 KV, NEXTN/MTP at boot then DFLASH2. Hopper fallback stays **4× H200** at the same 1M window if Secure Cloud has no 4× RTX PRO 6000.

Reminders codified: do not provision 2× for 1M, and do not buy 4× for a single 200k stream (leftover VRAM is concurrency, not speed). Reference band: 208 tok/s in-band (0xSero, NVFP4 MTP) at 1M configured.

## ADR-017 — Weights store is an encrypted volume disk

**Date:** 2026-09-04
**Status:** accepted
**Supersedes:** ADR-006 for the primary weights store

Weights live on an **encrypted volume disk** (≈400 GB, `Encrypt volume` at creation), attached at `/workspace`. Encryption key is Runpod-managed, no BYOK — accepted as **cold-storage defense in depth** only; runtime plaintext remains provider-trusted (ADR-016). No network volume (cannot use the encrypted-volume feature).

Consequences baked in:

- **Volume disk is pod-scoped.** Retained across stop/start of the pod lease; **deleting the pod deletes the weights.** Between sittings: stop the pod, never delete it.
- `HF_HUB_OFFLINE=1` after the first pull; weights are served from the volume, never re-downloaded.
- Not a High-Performance tier claim; that tier was tied to the ADR-006 network volume.

## ADR-016 — Provider-trusted mode accepted for now

**Date:** 2026-09-04
**Status:** accepted
**Qualifies:** ADR-014 (path 1)

ADR-014 path 1 is chosen: **provider-trusted**. We explicitly accept that Runpod, the host operator, or anyone with privileged access to the rented hardware could read runtime plaintext — prompts, completions, weights, and keys in guest/GPU memory. All traffic controls stay: Secure Cloud, Jupyter off, no HTTP ports, SGLang on `127.0.0.1`, bearer required, Tailscale ACL `:22` only, no proxy/SOCKS/Serve/Funnel, no prompt logging, `HF_HUB_OFFLINE=1` after the first pull.

Two standing rails:

- **Do not call this pod provider-blind.** The hard confidentiality requirement is not met by an ordinary pod; that is now an accepted residual, not a solved problem.
- If the privacy posture hardens later, provider-blind (CPU TEE + GPU CC + fresh attestation + attestation-gated key release) or owned hardware is the un-blocked path; **re-evaluate before uploading any data we cannot expose.**

## ADR-015 — Agent access: SGLang native tri-format, pi primary, vmui-only observability

**Date:** 2026-09-04 (decided in the 2026-09-03 pod-UX sitting)
**Status:** accepted

- **Wire:** SGLang natively serves `/v1/chat/completions`, `/v1/responses`, and `/v1/messages` (Anthropic). **No adapter** — no LiteLLM or proxy holds plaintext on the laptop.
- **Primary agent: pi** (`@earendil-works/pi-coding-agent`, repo `earendil-works/pi`, MIT, v0.84.x), on the laptop AND in the pod with an identical `~/.pi/agent/models.json` (`baseUrl http://127.0.0.1:8000/v1`, `contextWindow 1048576`, `compat.supportsDeveloperRole: false`; not `@mariozechner/pi`). Full tools; `PI_OFFLINE=1`; `GLM_API_KEY` is the one env var. Pod instance runs in tmux and talks only to `127.0.0.1:8000`.
- **Observability: VictoriaMetrics vmui only** (no Grafana binary) on `:8428`, loopback; `nvidia_gpu_exporter` + `node_exporter` stay scrape-only in-pod. Boot SGLang with `--enable-metrics --enable-mfu-metrics`; raise TTFT/E2E histogram buckets above the stock 30 s for long prefills.
- **One tunnel:** `ssh -L 8000 + 8428` over Tailscale `:22` (ADR-012).
- **Security:** never scrape `/get_server_info` (CVE-2026-15977 echoes the API key); `/workspace/logs` mode 700 with size-capped rotation; optional distinct `--admin-api-key`; `/metrics` bypasses bearer by design (ok only because loopback). First-sitting smoke test for the sglang#36669 thinking-degeneration risk; temperature ≥ ~1 for tool calls.

## ADR-014 — Disk encryption does not make ordinary Runpod provider-blind

**Date:** 2026-09-03
**Status:** accepted
**Qualifies:** ADR-006, ADR-011, and ADR-012

The hard privacy requirement is that Runpod, its host operator, or someone with privileged access to the rented hardware must not be able to read prompts, completions, model weights, or keys.

Runpod’s storage documentation says:

- **Volume disk** can use the console’s encrypted-volume option, but Runpod stores the key, the key cannot be retrieved, and BYOK is unsupported.
- **Container disk and network volumes** cannot use that encrypted-volume feature.
- Runpod’s security controls and host-access policy are valuable isolation and governance controls, not a cryptographic guarantee against a privileged host operator.

Disk or file encryption protects data while it is cold. Inference necessarily puts plaintext and a decryption key into guest memory and GPU memory. An ordinary pod therefore cannot satisfy the hard requirement, even if we encrypt the model before upload or select Runpod’s encrypted volume disk. SSH, Tailscale, loopback binding, and disabled logs protect the request path and reduce accidental retention; they do not protect runtime memory from the host.

**Decision:** do not call an ordinary Runpod Secure Cloud pod private from Runpod. Before provisioning, choose one of:

1. **Provider-trusted mode:** explicitly accept Runpod as trusted for runtime plaintext. If cold-storage defense-in-depth is desired, use an encrypted **volume disk** rather than a network volume, accept Runpod-managed keys, and never put prompts in logs.
2. **Provider-blind mode:** require a documented confidential-computing deployment with a CPU TEE (SEV-SNP or TDX), NVIDIA GPU confidential computing with protected VRAM/PCIe, fresh remote attestation, and customer-controlled or attestation-gated KMS key release.
3. **Own the hardware:** operate the host and storage ourselves.

NVIDIA documents a self-hosted RTX PRO 6000 Blackwell Server Edition validation using AMD SEV-SNP, GPU confidential computing, attestation, and model-key release. That proves the hardware class can participate in such a design, not that Runpod provides the complete service. Until Runpod confirms the exact GPU, data center, VM, attestation, and key-release path, **do not provision a standard pod under the provider-blind requirement**.

## ADR-013 — Serve at 200k or 1M only; pick the SKU to match

**Date:** 2026-09-03
**Status:** accepted
**Supersedes:** the 8k/64k pool in the ADR-004 recipe; 4× as the default SKU when the window is 1M

GLM-5.3-Flash’s native window is **1,048,576**. 8k / 32k / 64k are not serve targets. LocalMaxxing 300–1004 tok/s is ctx=8192 and is not the SLA.

Two legal configs (math in [`refs/context.md`](refs/context.md)):

| | Window | GPUs | KV | Spec at boot |
| --- | --- | --- | --- | --- |
| **A (cost)** | `--context-length 204800` | **2×** RTX PRO 6000 | bf16 | DFLASH2 k=8 |
| **B (native)** | `--context-length 1048576` | **4×** RTX PRO 6000 | bf16 | NEXTN/MTP, then DFLASH |

Do not provision 2× for 1M. Do not provision 4× for a single 200k stream (leftover VRAM is concurrency, not speed). Hopper fallback stays 4× H200 at the same two windows.

Pick A or B **before** `pod create`. Default if unspecified: **B** (native window). 200k on 2× is a tight estimate (~188 GB of 192, before any unmodeled allocator or DFLASH overhead) and has no published NVFP4 boot log.

## ADR-012 — API only via `ssh -L`; ACL :22; no Serve / SOCKS / Funnel

**Date:** 2026-09-02
**Status:** accepted
**Supersedes:** ADR-011 rank-3 Serve; the SOCKS line in the old boot snippet

Userspace Tailscale rewrites inbound `<tailscale-ip>:<port>` to `127.0.0.1:<port>`. A default `*:*` ACL therefore publishes SGLang to the tailnet with no Serve and no SOCKS. Close that with an ACL: laptop (or `autogroup:self`) → pod **:22 only**. Reach the API with **Tailscale SSH + `ssh -L`**. Do not start `--socks5-server`, `tailscale serve`, or Funnel. Do not make the pod an exit node.

First sitting: browser `tailscale up` (user device). Keep public TCP 22 as bootstrap and break-glass; day-to-day do not point clients at the public IP. `ssh.runpod.io` cannot local-forward.

## ADR-011 — SSH localhost-forward is rank 1; Tailscale is the overlay

**Date:** 2026-09-02
**Status:** accepted; Serve convenience superseded by ADR-012
**Supersedes:** ADR-009 (partial — kernel VPN still impossible)

Fewest third parties on first sitting: Secure Cloud, Jupyter off, no HTTP ports, bind `127.0.0.1`, API key, **direct TCP 22 + `ssh -L`**. After userspace Tailscale is up, day-to-day is Tailscale SSH + `-L` (ADR-012). Do not use Basic SSH via `ssh.runpod.io` as the daily path. Funnel / Cloudflare Tunnel / proxy still forbidden. Serve and SOCKS are now also forbidden (ADR-012).

## ADR-010 — Pin `UNCENSORED-NVFP4`; rbinrs is stale

**Date:** 2026-09-02
**Status:** accepted
**Supersedes:** ADR-005 mirror list

Primary id is **`dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4`** (2026-08-29 loop-fix, 2026-09-02 reupload). The ABLITERATED twin is advertised as the same CRACK but commits diverge — do not mix. **`rbinrs/…-ABLITERATED-NVFP4` is a pre-fix snapshot — do not download.** Draft `incoai/GLM-5.3-Flash-DFlash2` is CC BY-NC-ND; pin `7d74cdd`. Serve NVFP4 on **SGLang**, not vLLM-on-SM120 (U+FFFD, vllm#54150).

## ADR-009 — Userspace Tailscale is the private door; kernel VPN is impossible

**Date:** 2026-09-02
**Status:** superseded in part by ADR-011

Runpod will not map `/dev/net/tun` or `NET_ADMIN`. Kernel Tailscale/WireGuard is out. Userspace `tailscaled --tun=userspace-networking` still works. ADR-011 ranks **direct TCP 22 + `ssh -L`** first (fewer third parties) and Tailscale as the overlay. HTTP proxy, serverless, Funnel, and Cloudflare Tunnel remain forbidden. Details: [`refs/privacy.md`](refs/privacy.md).

## ADR-008 — Primary checkpoint is dealignai CRACK NVFP4, not orcarouter

**Date:** 2026-09-02
**Status:** accepted

orcarouter is more popular and better documented as a method paper. Their own benches still show 11–18% harmful refusal at low effort, and their NVFP4 drops MTP. dealignai reports HarmBench-320 at 0% on off/max, keeps a cracked MTP head, and is ungated. That matches both the uncensor goal and the SGLang+DFLASH2 speed track. orcarouter is a research alternate, not the served artifact. Details: [`refs/abliterated.md`](refs/abliterated.md).

## ADR-007 — 1004.9 tok/s is a ceiling, not the SLA

**Date:** 2026-09-02
**Status:** accepted

The LocalMaxxing run we are chasing (`cmtk0maew03mrp701oyaivvka`) is the fastest approved GLM-5.3-Flash result on that site. Its notes describe a locked attractor, n-gram proposals that skip the draft forward, clock locks, and best-of-6. We copy the **hardware + engine + flags**. We do not treat the headline number as the definition of done.

Done for speed = we can serve the abliterated model over the private tunnel and we have our own measured tok/s, TTFT, and VRAM on a real prompt.

## ADR-006 — Weights on a High-Performance network volume

**Date:** 2026-09-02
**Status:** accepted

FP8 ≈ 306 GiB, NVFP4 ≈ 180–230 GiB, plus the DFlash2 draft. Re-downloading from Hugging Face on every boot is slow, billable, and a privacy leak (HF sees the pull). The volume is created first, in the DC that has the GPUs, High-Performance tier (immutable after create). Pod `/workspace` is that volume.

We do **not** use Runpod host-side HF model cache. That feature is aimed at serverless and still involves Runpod's cache plane.

## ADR-005 — Abliterated NVFP4 is the primary checkpoint

**Date:** 2026-09-02
**Status:** superseded by ADR-010

Primary weights were listed as `dealignai/GLM-5.3-Flash-ABLITERATED-NVFP4` with rbinrs as a live mirror. ADR-010 pins **UNCENSORED-NVFP4** and marks rbinrs stale.

Draft (unchanged): `incoai/GLM-5.3-Flash-DFlash2`.

Fallback weights if NVFP4 will not load: `dealignai/GLM-5.3-Flash-UNCENSORED-FP8`.

We do not serve stock `zai-org/GLM-5.3-Flash` as the primary model. The public benchmark used stock weights; we accept that as the speed reference, not the served artifact.

CRACK notes: fully uncensored at reasoning off / max. Low effort is intentionally more conservative. Default `reasoning_effort` to `max`.

## ADR-004 — Speed track is SGLang + NVFP4 + DFLASH2 on 2× RTX PRO 6000 Blackwell

**Date:** 2026-09-02
**Status:** accepted

This is the only stack that has published 800–1004 tok/s on LocalMaxxing for this model. vLLM on the same 2× card sits in the 150–190 tok/s band. Official vLLM FP8 recipes target Hopper TP=4/8 and report ~163 tok/s single-stream (211 with MTP) on H200.

Fallback track (if Runpod has no Secure Cloud 2× RTX PRO 6000, or SGLang/SM120 will not boot): `vllm/vllm-openai:glm53-flash` + abliterated FP8 on 4× H200 (`HOPPER_141`).

Do not start on 8× 3090 or consumer cards. The model does not belong there for this project's speed goal.

## ADR-003 — SSH (or Tailscale) only. No HTTP proxy, no public TCP for the API

**Date:** 2026-09-02
**Status:** accepted

Runpod's HTTP proxy is public, unauthenticated, Cloudflare-fronted, and times out at 100s. That is incompatible with the privacy goal and with long generations.

The inference process binds `127.0.0.1:8000`. The laptop reaches it with:

```bash
ssh -N -L 8000:127.0.0.1:8000 <pod>
```

Tailscale/headscale is an allowed later upgrade (still no proxy ports). A bearer token is required even on the tunnel.

SSH itself uses Runpod TCP port 22. That is accepted: it carries encrypted traffic we initiate, not an open model API.

## ADR-002 — Dedicated Secure Cloud pod, never serverless, never Community Cloud

**Date:** 2026-09-02
**Status:** accepted

- **Pod** so the process stays up, we control the listen address, and we can SSH.
- **Secure Cloud** (T3/T4 DCs) for dedicated hardware and stable IPs. Community Cloud is cheaper and shared; rejected.
- **Not serverless:** every prompt would go through `api.runpod.ai`, be queued, and be retained for minutes. FlashBoot/host cache also spread weights onto Runpod-managed hosts we do not control.

Idle cost is the trade. Stop the pod when a sitting ends unless the user asks to keep it warm. The volume keeps the weights.

## ADR-001 — This repo is the operator scratchpad

**Date:** 2026-09-02
**Status:** accepted

Empty workspace, no app to ship. The directory exists so hardware choices, serve flags, measurements, and live resource IDs survive across chats. Prefer updating markdown + JSON snapshots over building automation until a recipe has been measured once.
