# Status

Last updated: 2026-09-04 (reseller list ADR-026; API window 512k / ADR-025; SGLang serving)

## One-liner

Config B is **serving** GLM-5.3-Flash UNCENSORED-NVFP4 on Secure Cloud **4× RTX PRO 6000**. API is **`127.0.0.1:8000` only**; reach it with `ssh -L`, not a proxy. Provider-trusted (ADR-016). **No MTP** (sglang#36599). **API max context is 512k (`524288`)** (ADR-025) so usage can hit 100% — do not advertise 1M. Omit `max_tokens` caps at **65536** (ADR-023). Do not claim 208 or 1004 tok/s.

Live pod id / SSH endpoint: `.env` (`RUNPOD_POD_ID`, `SSH_HOST`, `SSH_PORT`) and [`runpod/inventory.local.md`](runpod/inventory.local.md). Do not paste them into tracked files.

## Research conclusions

| Stream | Decision |
| --- | --- |
| Context | SKU menu is **200k or 1M** (ADR-013). **This boot serves 512k (`524288`)** (ADR-025) so the usage bar can fill. 1M advertised but the DSA indexer OOMs ~655k–825k. |
| Speed | SGLang + NVFP4 on RTX PRO 6000. Long-ctx SLA is **not** 300–391 (that is 8k). In-band: **~150 tok/s** (2× EXL3 analog at 229k) to **208 tok/s** (4× NVFP4 MTP, 1M configured). DFLASH2 at 200k/1M is unmeasured. |
| Weights | **`dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4`** (not rbinrs, not mixed with ABLITERATED twin) + `incoai/GLM-5.3-Flash-DFlash2` @ `7d74cdd`. `reasoning_effort=max`. |
| Privacy | **Provider-trusted (ADR-016).** Weights on an **encrypted volume disk** (ADR-017) — Runpod-managed key, no BYOK, cold-storage defense in depth only. Runtime plaintext remains trusted-to-Runpod; not provider-blind. SSH/Tailscale/no-proxy controls protect the request path. ADR-014. |
| Research | **Flash UNCENSORED @ 1M stays primary** (ADR-019). CyberGym 84.5% is 753B and does not fit. Upgrade is the local harness, not a model swap. [`refs/red-team.md`](refs/red-team.md). |
| LoRA | **Do not attach one** (ADR-020). Zero Flash PEFT adapters on HF. The one “Flash LoRA” is a llama.cpp Heretic GGUF with 26% residual refusal — worse than CRACK 0%, wrong engine. Cyber LoRAs are GLM-4.7 / Qwen3. mHC fights low-rank residual edits. |
| Harness | **pi + local XPI slice** (ADR-021). `@xaccefy/pi-casefile` + `@xaccefy/pi-xtodo`, `/xp lite`. Not the `@xaccefy/pi-xpi` umbrella (webxp / preview.is). Not CAI / Strix / OpenCode-in-pod. |
| Ops | **Dumb snapshot + short pi `/ops`** (ADR-022). `/workspace/ops/LATEST.md` over SSH. vmui stays the only dashboard. No Grafana, no pi HTTP UIs, no `/health` loop, no auto-restart of SGLang unless a flag file exists. |
| Decode UX | **65k omit-cap, 16k content reserve, 128k prefill batches** (ADR-023). **API window 512k** (ADR-025) so usage can hit 100%. Do not `--allow-auto-truncate`. Overnight extra think: `custom_params.thinking_budget: -1`. |
| Pricing | **Busy list $0.35 / $0.038 / $47 per MTok** (input / cached / output, +20% on this boot’s GPU-seconds). Reserved **$10.10/hr**. Do not match Z.ai $0.15/$0.50. [`refs/pricing.md`](refs/pricing.md), ADR-026. |

Full writeups: [`refs/context.md`](refs/context.md), [`refs/speed.md`](refs/speed.md), [`refs/abliterated.md`](refs/abliterated.md), [`refs/privacy.md`](refs/privacy.md), [`refs/red-team.md`](refs/red-team.md), [`refs/ops.md`](refs/ops.md), [`refs/pricing.md`](refs/pricing.md). **Pod UX design (2026-09-03)**: one SSH tunnel carries the API (SGLang natively serves OpenAI chat-completions, Responses, and Anthropic Messages wire formats — no adapter) and VictoriaMetrics/vmui observability; pi in tmux is the in-pod chat harness; `/get_server_info` leaks the api key (CVE-2026-15977) — never scrape it; details in [`sessions/2026-09-03-pod-ux.md`](sessions/2026-09-03-pod-ux.md).

## Live resources

Shape only — IDs are local. See [`runpod/inventory.md`](runpod/inventory.md).

- Private template named `glm-flash-1m` (console id in `.env` as `RUNPOD_TEMPLATE_ID`).
- Config B pod on Secure Cloud, 4× RTX PRO 6000, encrypted 400 GB volume at `/workspace`. Pod-scoped: **stop, never delete**.
- SGLang: `127.0.0.1:8000`, bearer required, **512k** bf16 KV (ADR-025). `max_prefill_tokens=131072`, `chunked_prefill_size=16384`. Tunnel: `scripts/ssh-tunnel.sh` (or `ssh -N -L 8000:127.0.0.1:8000 -L 8428:127.0.0.1:8428`).

## Privacy review (this boot)

- Provider-trusted (ADR-016), Secure Cloud, Jupyter off, no HTTP ports advertised, process on `127.0.0.1:8000`, bearer on, telemetry env off, weights on the volume, sample via `ssh -L` not proxy / not `100.x:8000`, encrypted volume accepted as Runpod-keyed, `swapon` empty.
- Residual: platform HTTP sidecar mapping (nothing in-guest listens), MooseFS ignores unix modes on `/workspace/secrets`, Tailscale not installed yet (direct TCP `:22` only), NUMA affinity skipped (no `SYS_NICE`), `--enable-custom-logit-processor` (loopback + bearer).

## Blocked on

- MTP still blocked on this image (sglang#36599). Tailscale auth key still optional.
- A 1M *chat* is not served on this boot (ADR-025). DSA indexer CUDA OOM was measured at ~825k / 16k prefills and ~655k / 100k prefills while the flag was still 1,048,576.

## Last measurement

Long chat (while still 1M-configured): **39/39** through **825,511**, then DSA indexer OOM. **This boot:** `--context-length 524288`, `/v1/models` **`max_model_len`: 524288**, idle VRAM ~73 GB × 4, `available_gpu_mem=24.66 GB` (was 17.96 GB at 1M). Smoke: 17→36 tokens, `finish=stop`, `content=ready`. Raw JSON stays under local `logs/` (gitignored).

## Next action

1. Point pi at `sglang-loopback` / `glm-5.3-flash` (`http://127.0.0.1:8000/v1`). Bearer is `GLM_API_KEY`. Never scrape `/get_server_info`.
2. Smoke: pi multi-tool (sglang#36669), Codex `/v1/responses`, glm47 streaming.
3. After pi talks to the loopback API: `pi install npm:@xaccefy/pi-casefile` and `pi-xtodo` (ADR-021); `/xp lite` smoke. Do not install `pi-webxp`.
4. Copy `configs/ops-snapshot.sh` onto `/workspace/ops/` and start the 60s loop in tmux (ADR-022). Do not create `AUTO_RESTART` unless asked.
5. **Stop** (do not delete, do not `--terminate-after`) when the sitting ends unless told to keep it warm.
