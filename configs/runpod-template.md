# Runpod template `glm-flash-1m`

Console: <https://console.runpod.io/user/templates> (private, NVIDIA, Pod). Look up the id at deploy time; do not commit it.

Created 2026-09-04 in the web console. Encryption, GPU count, and data center are **not** template fields — set them at each deploy.

## Frozen fields

| Field | Value |
| --- | --- |
| Image | `lmsysorg/sglang:glm-5.3-flash@sha256:a2c0f7d4d9ebce97a2707c5415081d284d741db1033a1008a955453b9b5255bf` |
| Container disk | 50 GB (wiped on stop) |
| Volume disk | 400 GB at `/workspace` |
| HTTP ports | none |
| TCP ports | `22/tcp` labeled SSH |
| Jupyter | off (`startJupyter: false`) |
| SSH key injection | on (`startSsh: true` → `PUBLIC_KEY`) |
| Public | false |
| Recommended GPUs | 1) RTX PRO 6000  2) H200 SXM |

Env (non-secret):

```text
SGLANG_OPT_DEEPGEMM_HC_PRENORM=0
SGLANG_ENABLE_JIT_DEEPGEMM=0
HF_HUB_DISABLE_TELEMETRY=1
NCCL_IB_DISABLE=1
HF_HOME=/workspace/hf
HF_XET_HIGH_PERFORMANCE=1
```

Start command (official custom-image SSH recipe plus optional volume boot hook):

```bash
bash -c 'apt update; DEBIAN_FRONTEND=noninteractive apt-get install openssh-server -y; mkdir -p ~/.ssh; chmod 700 ~/.ssh; echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys; service ssh start; if [ -x /workspace/boot.sh ]; then /workspace/boot.sh & fi; sleep infinity'
```

## Deploy-time (every recreate)

These cannot live on the template. Official storage docs: encrypt is a checkbox **only in the Pod creation flow**. REST `PodCreateInput` has no `volumeEncrypted`.

1. Secure Cloud, never Community, never Serverless.
2. GPU: **NVIDIA RTX PRO 6000 Blackwell Server Edition**, **4×** (config B / ADR-018).
3. DC: `EUR-IS-2` (Medium stock 2026-09-04) or `EUR-IS-1`.
4. **Encrypt volume** ON.
5. Jupyter off, SSH on, no HTTP ports (template already empty).
6. Name: `glm-flash-1m`.

Between sittings: **stop**, never delete. Deleting the Pod deletes the encrypted volume and the weights.

## Restart vs recreate

- **Restart (stop → start):** same Pod, same encrypted `/workspace`. `boot.sh` runs if you installed it.
- **Recreate (new Pod from this template):** empty volume. Re-tick Encrypt volume. Re-pull weights.

Reach the API with `ssh -L 18000:127.0.0.1:8000` (and `18428:127.0.0.1:8428` for vmui). Laptop clients use `:18000` so they do not steal local `:8000`. Never `*.proxy.runpod.net`.
