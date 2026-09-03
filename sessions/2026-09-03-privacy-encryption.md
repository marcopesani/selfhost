# Session 2026-09-03 — provider-blind privacy and disk encryption

## Goal

Determine whether Runpod disk encryption can prevent Runpod or the owner/operator of the rented hardware from reading prompts, completions, model weights, or other contents.

## What I did

Checked the current Runpod storage and security docs plus NVIDIA’s confidential-computing reference:

- Runpod’s **volume disk** can use the console’s encrypted-volume option, but Runpod stores the key, the key cannot be retrieved, and BYOK is unsupported.
- Runpod’s storage page says container disks and network volumes cannot use that encrypted-volume feature. A separate Runpod security guide broadly claims platform data is encrypted at rest; neither source provides customer-controlled keys or runtime confidentiality.
- Encryption protects cold storage. During inference, plaintext weights, prompts, activations, and a decryption key exist in guest/GPU memory.
- NVIDIA’s self-hosted reference validates RTX PRO 6000 Blackwell Server Edition with AMD SEV-SNP, NVIDIA GPU confidential computing, attestation, and model-key release. This demonstrates a possible architecture, not Runpod support.

Sources: [`refs/links.md`](../refs/links.md), [`refs/privacy.md`](../refs/privacy.md).

## What I measured

No runtime measurement. No pod or volume was created.

## Resources touched

- Pod: none
- Volume: none
- DC: none

## Decisions / ADR updates

- Added ADR-014: ordinary Runpod is **provider-trusted**, not provider-blind.
- Provider-blind mode requires CPU/GPU confidential computing, fresh remote attestation, and attestation-gated KMS key release; otherwise use hardware we operate.
- Durable privacy reference, status, README, agent instructions, and inventory notes were updated.

## Next

Ask Runpod to confirm the complete confidential-compute path for the exact GPU/DC: CPU TEE, GPU CC, attestation evidence, and KMS/key-release integration. If unavailable, explicitly accept provider-trusted Runpod or move to owned/confidential-compute hardware before provisioning.
