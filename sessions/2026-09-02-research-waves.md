# Session 2026-09-02 — three-stream research

## Goal

Fill the scratchpad with sourced answers on (1) max tok/s, (2) best uncensored checkpoint, (3) private Runpod access including Tailscale.

## What I did

Two waves of research agents plus direct fetches (LocalMaxxing API, HF catalog of 37 repos, vLLM recipe, sglang#37105, 0xSero README, orcarouter/dealignai/Blackfrost cards, Runpod security/storage/ports docs, Tailscale userspace KB, runpodctl#272). Firecrawl CLI had a stale token; browser login was left open and unused.

Wrote `refs/speed.md`, `refs/abliterated.md`, `refs/privacy.md`, `refs/links.md`. ADRs 008–009. Canvas comparison.

## What I measured

None on our hardware. Catalogued published numbers only.

## Resources touched

None billable.

## Decisions / ADR updates

- ADR-008: dealignai CRACK NVFP4 is primary (not orcarouter)
- ADR-009: userspace Tailscale + localhost; kernel VPN impossible

## Wave 2 merge

Folded [Speed: GLM tok/s](052a6e52-fbde-4fa1-9bf4-34cff1317951), [Abliterated GLM variants](854390cd-ac80-42c0-8eb6-7bcf1be65d5e), [Runpod Tailscale privacy](e119a05c-dd90-43f3-b63f-f764b5e15fa7), [Speed wave 2 deep dive](7ea62ed3-af16-4f03-a61d-53f10e0a4ae9), [Abliterated wave 2 compare](68ed672b-b74e-4388-ac6e-f42dfa30b5a5), [Privacy wave 2 Tailscale](136489b3-a5b4-43a2-8b62-3a155f02338e) into the briefs.

Corrections: start DFLASH at k=8 (300.7 / 373–391); pin UNCENSORED not rbinrs; SSH-L is rank 1; DFlash2 is CC BY-NC-ND; vLLM+ModelOpt on SM120 is U+FFFD; userspace netstack publishes localhost — ACL :22, no Serve/SOCKS.

## Next

Provision. Stop reading.
