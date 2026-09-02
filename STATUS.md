# Status

Last updated: 2026-09-02 (research waves 1–2 written; no pod yet)

## One-liner

Reference repo is populated. **No Runpod resources exist.** Next sitting is auth + GPU stock, not more literature.

## Research conclusions

| Stream | Decision |
| --- | --- |
| Speed | SGLang + NVFP4 + DFLASH2 **k=8** on 2× RTX PRO 6000. Honest band **300–391** (their steady-state). 443+ is best-of-N. 1004 is an attractor. vLLM floor ~150–190. Hopper fallback ~160–210. |
| Weights | **`dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4`** (not rbinrs, not mixed with ABLITERATED twin) + `incoai/GLM-5.3-Flash-DFlash2` @ `7d74cdd`. `reasoning_effort=max`. |
| Privacy | First sitting: TCP 22 + `ssh -L`. Day-to-day: Tailscale SSH + `-L`, **ACL :22 only**. No Serve / SOCKS / Funnel. Jupyter off. |

Full writeups: [`refs/speed.md`](refs/speed.md), [`refs/abliterated.md`](refs/abliterated.md), [`refs/privacy.md`](refs/privacy.md). Canvas: research comparison beside chat.

## Live resources

None. See [`runpod/inventory.md`](runpod/inventory.md).

## Blocked on

- `runpodctl user` succeeding in the session that will provision
- Secure Cloud stock for 2× RTX PRO 6000 Blackwell (else 4× H200)
- Tailscale auth key (optional; login URL works)
- HF token only if a gated fallback is chosen (primary is ungated)

## Last measurement

None of ours. Ceiling reference: LocalMaxxing `cmtk0maew03mrp701oyaivvka`.

## Next action

1. `runpodctl version && runpodctl user && runpodctl gpu list --include-unavailable`
2. Pick DC with 2× RTX PRO 6000 Secure Cloud
3. High-Performance volume (~400 GB) in that DC
4. SSH-only pod, no HTTP ports
5. Pull `UNCENSORED-NVFP4` + DFlash2 (`7d74cdd`) onto the volume
6. Jupyter off. SGLang on `127.0.0.1`. First access via TCP 22 + `ssh -L`. Then userspace Tailscale (browser login) + ACL :22. Never Serve/SOCKS.
7. Measure a real prompt; write `logs/` + a row in `refs/speed.md`
