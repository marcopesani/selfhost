# Session 2026-09-03 — clamp serve window to 200k or 1M

## Goal

Drop 8k/32k/64k from the plan. Re-run the hardware/speed analysis at **200k** and **1M** only.

## What I did

Sized KV from the hybrid architecture (34 KDA O(1) + 11 sparse MLA layers, `kv_lora_rank=512`) and 0xSero’s 7.4 KB/token fp8 pool. Compared that to LocalMaxxing 2× NVFP4 peaks (182–188 GB of 192 at ctx=8192). Wrote [`refs/context.md`](../refs/context.md), ADR-013, recipes, STATUS, AGENTS, README. Canvas beside chat.

## What I measured

None on our hardware. In-band published: 0xSero 208 tok/s on 4× at 1M configured; LocalMaxxing 2× EXL3 ~150 tok/s at 229k–353k (wrong quant).

## Resources touched

None billable.

## Decisions / ADR updates

- ADR-013: two legal configs — A 2×/200k, B 4×/1M (default). No 8k/64k pool. No 1M on 2× NVFP4.

## Next

User picks A or B, then `runpodctl user` + GPU stock.
