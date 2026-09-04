# Agent instructions

This directory is a **scratchpad**, not a product repo. Continue the self-host sitting. Current boot, constraints, and next action are in [`STATUS.md`](STATUS.md). Architecture choices are in [`DECISIONS.md`](DECISIONS.md). Do not copy findings or ADR conclusions into this file.

## First 60 seconds

1. Read [`STATUS.md`](STATUS.md). That is the live truth.
2. Read [`DECISIONS.md`](DECISIONS.md). Do not reverse an ADR without writing a new one.
3. If the user mentions a past sitting, read the latest file in [`sessions/`](sessions/) (local-only; gitignored).
4. Check [`runpod/inventory.md`](runpod/inventory.md) (shape) and local `.env` / `runpod/inventory.local.md` (live IDs) before creating any billable resource.
5. Topic writeups live under [`refs/`](refs/). Read the matching file before answering. Do not re-litigate without a new measurement or a new ADR.

## Hard rules

- Follow ADRs in [`DECISIONS.md`](DECISIONS.md). A faster or cheaper sitting that breaks one is a failed sitting.
- Do not create a Community Cloud pod or a serverless endpoint. Do not add HTTP ports. Do not hand the user a `*.proxy.runpod.net` URL.
- Bind the inference process to `127.0.0.1` only. Reach it with `ssh -L`. Do not curl a Tailscale IP, Serve, SOCKS, or Funnel.
- Do not commit `.env`, `secrets/`, API keys, SSH keys, or model weights.
- Do not commit live instance identifiers: pod id, template id, public IP, SSH port, or SSH key paths. Those belong in `.env` and optional `runpod/inventory.local.md`. Session notes are gitignored for the same reason.
- Privacy mode (provider-trusted vs provider-blind) is an ADR. Do not claim the other mode. Before any "it is up" message, complete the checklist below.
- Do not skip the cost guard in [`runpod/cost.md`](runpod/cost.md). Pods bill while running. Stop, delete, or `--terminate-after` per that file and [`STATUS.md`](STATUS.md) unless the user says keep it warm.
- Do not treat "Running" in the console as success. Success is a completion returned over the SSH tunnel.
- Use `runpodctl` (or Runpod MCP if connected). Prefer `runpodctl pod create --wait`. Check live `--help`; do not invent flags.

## What to write down

Every sitting that changes state must:

1. Create or update a local `sessions/YYYY-MM-DD-<slug>.md` from [`sessions/_template.md`](sessions/_template.md). Session notes are gitignored — they pick up live SSH endpoints.
2. Update `STATUS.md` (what exists, what failed, next action). No pod ids, IPs, or SSH ports.
3. If a resource was created or destroyed, update local `runpod/inventory.local.md` and `.env`. Keep tracked `runpod/inventory.md` as the empty shape.
4. If an architecture choice changed, add an ADR in `DECISIONS.md`.
5. If a measurement was taken, append a row to `refs/benchmark.md` (our runs section) and drop the raw JSON in `logs/` (gitignored).

## Provision order

Volume first, then compute in that same data center. Never the reverse. SKU, window, and engine flags are in [`DECISIONS.md`](DECISIONS.md) and [`configs/`](configs/).

```text
verify or record privacy mode (ADR)
→ pick the SKU the ADRs bind
→ pick DC with that SKU on Secure Cloud
→ create storage there
→ create pod attached to that storage, SSH only, no HTTP ports
→ download weights once onto the volume
→ start the server on 127.0.0.1 with the bound context length
→ SSH tunnel from the laptop
→ measure a prompt in-band
```

## Speed vs honesty

Reproduce the **command and hardware**, then report our own numbers. Do not claim we matched a published tok/s figure unless we ran the same protocol and got it. What counts as in-band, and which public numbers are ceiling-only, is in [`refs/speed.md`](refs/speed.md).

## Privacy review before any "it is up" message

- [ ] Privacy mode is explicit: provider-trusted or provider-blind (must match the ADR)
- [ ] Secure Cloud
- [ ] Jupyter off
- [ ] No HTTP ports / no proxy URL
- [ ] Process listening on `127.0.0.1` only
- [ ] Bearer token required
- [ ] Telemetry off
- [ ] Weights on the volume, not re-downloaded
- [ ] Tailnet ACL :22 only (userspace otherwise publishes localhost)
- [ ] No SOCKS / Serve / Funnel / exit node
- [ ] Sample request via `ssh -L` to `127.0.0.1`, not `http://100.x:8000`, not the proxy
- [ ] Provider-trusted only: encrypted volume disk if cold-storage encryption is required; accept Runpod-managed key and runtime access
- [ ] Provider-blind only: exact CPU TEE, GPU CC, fresh attestation, and attestation-gated KMS key release verified
- [ ] `swapon --show` is empty or otherwise verified not to receive prompts

## Out of scope unless the user asks

Publishing a site, opening a PR, committing, or building a UI. The primary checkpoint is the one in [`DECISIONS.md`](DECISIONS.md); do not swap it unless the user asks and you write a new ADR.
