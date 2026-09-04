# Inventory

**Do not commit live IDs.** Pod id, template id, public IP, and SSH port belong in `.env` (and optionally [`inventory.local.md`](inventory.local.md), gitignored). This table is the shape only.

**Provider-trusted mode (ADR-016).** Weights store: encrypted **volume disk** (ADR-017) — Runpod-managed key, no BYOK, pod-scoped: stop the pod between sittings, never delete it.

| Kind | ID | DC | Notes |
| --- | --- | --- | --- |
| Pod template | — | — | Private `glm-flash-1m`. Image pin, 50 GB container / 400 GB volume @ `/workspace`, `22/tcp` only, Jupyter off, SSH on. Does **not** include encrypt / GPU count / DC. Operator copy: [`configs/runpod-template.md`](../configs/runpod-template.md). |
| Encrypted volume disk | — (pod-scoped) | — | 400 GB @ `/workspace`. Stop-pod keeps it; delete-pod deletes weights. Guest MooseFS does not enforce unix modes. |
| Pod | — | — | Secure Cloud, 4× RTX PRO 6000, SSH only, Jupyter off, no HTTP ports. This boot: `--context-length 524288` (ADR-025). Do not `--terminate-after` on the weights lease. |
| Tailscale node | — | — | Hostname `glm-flash`, state on `/workspace/tailscale`. |
