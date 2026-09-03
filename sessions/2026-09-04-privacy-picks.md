# Session 2026-09-04 — gate decisions: provider-trusted, encrypted disk, config B

## Goal

Close the ADR-014 gate and the A/B config choice so provisioning can start. Pure decision +
record-keeping sitting; no resources created, no measurements.

## What I did

User picked, I recorded:

1. **Privacy: Provider-trusted** (ADR-014 path 1, ADR-016).
2. **Storage: Encrypted volume disk** — Runpod-managed key, no BYOK, cold-storage defense in depth (ADR-017). Note: this supersedes the ADR-006 network-volume plan for the weights store; the volume is pod-scoped, so delete-pod deletes-weights.
3. **Config: B — 1M native window (`1048576`) on 4× RTX PRO 6000** (ADR-018).

Wrote: DECISIONS.md ADR-015–018, STATUS.md, runpod/inventory.md, this session file.

Verified `runpodctl` availability (2.12.0-51ca7f0) — next step is `runpodctl user` in the provisioning session.

## What I measured

| tok/s out | TTFT | VRAM | prompt | notes |
| --- | --- | --- | --- | --- |
| — | — | — | — | none (no pod) |

## Resources touched

- Pod: none
- Volume: none
- DC: none

## Decisions / ADR updates

- ADR-015 — agent access: SGLang native tri-format, pi primary (laptop + pod), vmui-only observability.
- ADR-016 — provider-trusted mode accepted (ADR-014 path 1).
- ADR-017 — weights store is an encrypted volume disk (supersedes ADR-006 for the weights store).
- ADR-018 — config B binding: 1M / 4× RTX PRO 6000.

## Next

1. `runpodctl user`, `runpodctl gpu list --include-unavailable`, pick DC with 4× RTX PRO 6000 on Secure Cloud (Hopper fallback: 4× H200).
2. Create encrypted volume disk (~400 GB) in that DC — no High-Performance tier (that was the network-volume claim, ADR-017).
3. Create pod: SSH only, Jupyter off, no HTTP ports, attach volume.
4. Pull weights once on the volume; `HF_HUB_OFFLINE=1`.
5. Boot SGLang on `127.0.0.1` with `--enable-metrics --enable-mfu-metrics`, raised TTFT/E2E histogram buckets.
6. SSH tunnel `:8000` + `:8428`; measure a long prompt in-band; write `logs/` + a row in `refs/benchmark.md`.
7. First-sitting smoke tests: pi multi-tool session (#36669), Codex on `/v1/responses`, pi tool-call streaming.
8. Observability stack (vmui + exporters) from the pod-UX design.