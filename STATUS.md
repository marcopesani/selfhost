# Status

Last updated: 2026-09-04 (gate decisions: provider-trusted, encrypted volume disk, config B)

## One-liner

Reference repo is populated. **No Runpod resources exist yet.** The privacy posture is now **provider-trusted** (ADR-016), weights will live on an **encrypted volume disk** (ADR-017), and the **B** config (1M / 4× RTX PRO 6000) is binding (ADR-018). Gate is closed: next sitting provisions the volume then the pod. See [`sessions/2026-09-04-privacy-picks.md`](sessions/2026-09-04-privacy-picks.md).

## Research conclusions

| Stream | Decision |
| --- | --- |
| Context | **200k (`204800`) or 1M (`1048576`) only.** 8k–64k discarded. Math: [`refs/context.md`](refs/context.md). ADR-013. |
| Speed | SGLang + NVFP4 on RTX PRO 6000. Long-ctx SLA is **not** 300–391 (that is 8k). In-band: **~150 tok/s** (2× EXL3 analog at 229k) to **208 tok/s** (4× NVFP4 MTP, 1M configured). DFLASH2 at 200k/1M is unmeasured. |
| Weights | **`dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4`** (not rbinrs, not mixed with ABLITERATED twin) + `incoai/GLM-5.3-Flash-DFlash2` @ `7d74cdd`. `reasoning_effort=max`. |
| Privacy | **Provider-trusted (ADR-016).** Weights on an **encrypted volume disk** (ADR-017) — Runpod-managed key, no BYOK, cold-storage defense in depth only. Runtime plaintext remains trusted-to-Runpod; not provider-blind. SSH/Tailscale/no-proxy controls protect the request path. ADR-014. |

Full writeups: [`refs/context.md`](refs/context.md), [`refs/speed.md`](refs/speed.md), [`refs/abliterated.md`](refs/abliterated.md), [`refs/privacy.md`](refs/privacy.md). Canvases: research comparison + 200k/1M VRAM beside chat. **Pod UX design (2026-09-03)**: one SSH tunnel carries the API (SGLang natively serves OpenAI chat-completions, Responses, and Anthropic Messages wire formats — no adapter) and VictoriaMetrics/vmui observability; pi in tmux is the in-pod chat harness; `/get_server_info` leaks the api key (CVE-2026-15977) — never scrape it; details in [`sessions/2026-09-03-pod-ux.md`](sessions/2026-09-03-pod-ux.md).

## Live resources

None. See [`runpod/inventory.md`](runpod/inventory.md).

## Blocked on

- Nothing decision-wise. UX picks are ADR-015, privacy is ADR-016, storage is ADR-017, config is ADR-018.
- Next hard gate: **`runpodctl user` + Secure Cloud stock for 4× RTX PRO 6000** (Hopper fallback 4× H200) in the provisioning session.
- Tailscale auth key (optional; login URL works)
- HF token only if a gated fallback is chosen (primary is ungated)

## Last measurement

None of ours. Ceiling reference (8k, out of band): LocalMaxxing `cmtk0maew03mrp701oyaivvka`. In-band reference: 0xSero 208 tok/s on 4× at 1M configured.

## Next action

1. `runpodctl user` and `runpodctl gpu list --include-unavailable`; pick DC with 4× RTX PRO 6000 on Secure Cloud (Hopper fallback: 4× H200 at the same 1M window).
2. **Create the encrypted volume disk first** (~400 GB, `Encrypt volume`) in that DC. Not a network volume: no High-Performance tier, pod-scoped — stop the pod between sittings, never delete it (weights live there, ADR-017).
3. Create the pod: Secure Cloud, SSH-only, no HTTP ports, Jupyter off, attach the volume, `--terminate-after` on experimental runs.
4. Pull weights once onto the volume; `HF_HUB_OFFLINE=1` after.
5. Boot SGLang on `127.0.0.1` with `--enable-metrics --enable-mfu-metrics`; raise TTFT/E2E histogram buckets above the stock 30 s (long-prefill p99 pegs at +Inf otherwise).
6. SSH tunnel `:8000` + `:8428`; measure a **long** prompt in-band; write `logs/` + a row in `refs/benchmark.md`.
7. First-sitting smoke tests: pi multi-tool session (sglang#36669 thinking-degeneration risk), Codex tool calls on `/v1/responses`, pi tool-call streaming via the glm47 parser.
8. Observability stack (VictoriaMetrics vmui + exporters) from the pod-UX design.
