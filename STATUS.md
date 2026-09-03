# Status

Last updated: 2026-09-03 (context clamped; provider-blind encryption researched; no pod yet)

## One-liner

Reference repo is populated. **No Runpod resources exist.** The new hard privacy requirement is not met by an ordinary Runpod pod; verify confidential computing or explicitly accept provider trust before provisioning. Do not provision an 8k/64k pool.

## Research conclusions

| Stream | Decision |
| --- | --- |
| Context | **200k (`204800`) or 1M (`1048576`) only.** 8k–64k discarded. Math: [`refs/context.md`](refs/context.md). ADR-013. |
| Speed | SGLang + NVFP4 on RTX PRO 6000. Long-ctx SLA is **not** 300–391 (that is 8k). In-band: **~150 tok/s** (2× EXL3 analog at 229k) to **208 tok/s** (4× NVFP4 MTP, 1M configured). DFLASH2 at 200k/1M is unmeasured. |
| Weights | **`dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4`** (not rbinrs, not mixed with ABLITERATED twin) + `incoai/GLM-5.3-Flash-DFlash2` @ `7d74cdd`. `reasoning_effort=max`. |
| Privacy | SSH/Tailscale/no-proxy controls protect traffic, not a privileged host. Runpod volume-disk encryption is provider-managed/no-BYOK; network volumes cannot use that feature. Provider-blind mode needs CPU/GPU confidential computing, attestation, and gated key release. ADR-014. |

Full writeups: [`refs/context.md`](refs/context.md), [`refs/speed.md`](refs/speed.md), [`refs/abliterated.md`](refs/abliterated.md), [`refs/privacy.md`](refs/privacy.md). Canvases: research comparison + 200k/1M VRAM beside chat.

## Live resources

None. See [`runpod/inventory.md`](runpod/inventory.md).

## Blocked on

- Confirming whether Runpod offers provider-blind confidential VM/GPU, fresh attestation, and attestation-gated key release for the exact SKU/DC; public docs do not establish it.
- If not, choosing a provider-trusted downgrade or moving to owned/confidential-compute hardware.
- Choosing config **A** (2× / 200k) vs **B** (4× / 1M). Default if unspecified: **B**.
- `runpodctl user` succeeding in the session that will provision
- Secure Cloud stock for that SKU (else 4× H200 at the same window)
- Tailscale auth key (optional; login URL works)
- HF token only if a gated fallback is chosen (primary is ungated)

## Last measurement

None of ours. Ceiling reference (8k, out of band): LocalMaxxing `cmtk0maew03mrp701oyaivvka`. In-band reference: 0xSero 208 tok/s on 4× at 1M configured.

## Next action

1. Ask Runpod to confirm the exact confidential-compute, attestation, and key-release path for the target GPU/DC.
2. If unsupported, either record **provider-trusted mode** (no hard provider-blind guarantee) or switch to owned/confidential-compute hardware.
3. Only after that gate: choose A (200k/2×) or B (1M/4×), default B.
4. `runpodctl version && runpodctl user && runpodctl gpu list --include-unavailable`
5. Pick DC with that SKU on Secure Cloud.
6. If provider-trusted mode: choose encrypted volume disk for cold-storage defense in depth; do not use a network volume when customer-visible disk encryption is required.
7. SSH-only pod, no HTTP ports; pull weights; Jupyter off; SGLang on `127.0.0.1`; tunnel with `ssh -L`.
8. Measure a **long** prompt in-band; write `logs/` + a row in `refs/benchmark.md`.
