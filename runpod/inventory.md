# Inventory

No live resources as of 2026-09-04. **Provider-trusted mode (ADR-016).** Weights store: encrypted **volume disk** (ADR-017) — Runpod-managed key, no BYOK, pod-scoped: stop the pod between sittings, never delete it.

| Kind | ID | DC | Notes |
| --- | --- | --- | --- |
| Encrypted volume disk | — | pick w/ 4× RTX PRO 6000 | ~400 GB, `Encrypt volume` at creation. No High-Performance tier (that was the ADR-006 network-volume claim). Attach at `/workspace`. Delete-pod ⇒ delete-weights. |
| Pod | — | same DC | Secure Cloud, SSH only, Jupyter off, no HTTP ports; config **B**: `--context-length 1048576`, 4× RTX PRO 6000 (ADR-018). Hopper fallback 4× H200. `--terminate-after` on experimental runs. |
| Tailscale node | — | — | Hostname `glm-flash`, state on `/workspace/tailscale` |
