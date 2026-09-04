# Cost guard

A 2× RTX PRO 6000 (config A, 200k), 4× RTX PRO 6000 (config B, 1M), or 4× H200 pod bills by the second while running. 4× is roughly 2× the GPU bill of 2× — do not create B for a single 200k stream. The network volume bills monthly whether or not a pod is up.

Rules:

- Experimental pods get `--terminate-after` unless the user says keep warm.
- End of sitting: stop or delete the pod. Keep the volume.
- Do not set serverless `workers-min 1` (we are not using serverless).
- Confirm GPU hourly rate from `runpodctl gpu list` before create; do not guess.

Provenance (2026-09-04, `runpodctl gpu list` live, config B binding per ADR-018):

- RTX PRO 6000, Secure Cloud: **$2.09/GPU-hr → $8.36/hr for 4×** (~$67/8h sitting, ~$200/24h).
- RTX PRO 6000 WK: $2.19/GPU-hr → $8.76/4×.
- H200 SXM fallback: $4.59/GPU-hr → **$18.36/4×** — more than 2×; prefer 4× RTX PRO 6000.
- **Storage bills even idle**: per ADR-017 the weights store is an **encrypted volume disk**, which is pod-scoped. Volume disk is **$0.10/GB-month running, $0.20/GB-month stopped** (400 GB → $40 / $80). Container disk $0.10/GB-month. Fully loaded while up: **$8.42/hr**. The **network volume bills monthly whether or not a pod is up** — do not use it here. A stopped pod still rents the volume disk while the lease lives; deleting the pod deletes the disk and weights.

Reseller token list (20% over that stack, this boot’s tok/s): [`../refs/pricing.md`](../refs/pricing.md), ADR-026. Do not price from Z.ai.
