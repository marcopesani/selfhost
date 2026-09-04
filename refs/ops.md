# In-pod devops harness

Researched 2026-09-04. Question: how to maximize this inference pod’s
ability to **self-help, diagnose, observe, and report to a human**
without new HTTP ports, cloud MCP, or a second agent stack.

## Verdict

There is **no** open “in-pod SRE agent” worth installing next to the
weights. The constraint that matters: when SGLang is down, **pi cannot
talk**. The harness is therefore two layers (ADR-022):

| Layer | Runs when | Job |
| --- | --- | --- |
| Dumb snapshot | Always | Write `/workspace/ops/LATEST.md` every 60s |
| pi `pod-ops` | API up | Short diagnosis, MetricsQL, narrative report |

Observe with the stack already bound (ADR-015): SGLang `--enable-metrics`,
`nvidia_gpu_exporter`, `node_exporter` (in-pod scrape only), VictoriaMetrics
**vmui** on loopback `:8428`. Human graphs: `ssh -L 8428`. Agent queries:
`curl http://127.0.0.1:8428/api/v1/query`.

## Why not a specialized ops package

| Candidate | What it is | On this guest? |
| --- | --- | --- |
| **ops-snapshot.sh + `/ops` skill** | Files + existing pi | **Yes** |
| VictoriaMetrics vmui (already chosen) | MetricsQL UI + Prom API | **Yes** — only dashboard |
| `@spences10/pi-telemetry` | Local SQLite turn/tool timing | Optional, db on `/workspace/ops/` |
| `pi-debug-dashboard` | Browser UI `:9848`, SSE | No — extra HTTP listener |
| `disler/pi-agent-observability` | Bun HTTP UI + ingest | No — extra HTTP + another stack |
| `AaronL1011/pi-hub` | Session dashboard `:7420`, `wmctrl` | No — desktop/HTTP |
| Grafana / Prom stack from SGLang examples | Official, oversized | No — ADR-015 |
| dcgm-exporter | Better GPU metrics | No — privileges Runpod does not grant |
| Netdata / glances web | Host dashboards | No — HTTP |
| Datadog / Langfuse / Phoenix | Cloud APM | No — prompts/ops leave the box |
| k8s operators, systemd units | Not this guest | No — Runpod pod, `sleep infinity` |

XPI casefile stays the **research** ledger (ADR-021). Do not file GPU
Xids as `ConfirmFinding`. Ops uses markdown reports + optional xtodo in
the ops tmux window only.

## Self-help rules

- **Diagnose** from `LATEST.md`, `nvidia-smi`, `df`, `/metrics`, vmui.
- **Never** loop `GET /health` (sglang#35884 can pile orphaned 1-token
  health generates into the scheduler). A one-shot human check is fine.
- **Never** `GET /get_server_info` (CVE-2026-15977).
- **Never** grep `sglang.log` for config — the startup line prints the
  API key. Read `/metrics` and process state instead.
- **Restart SGLang** only if `/workspace/ops/AUTO_RESTART` exists, or
  the human runs `/workspace/boot.sh`. Default off.
- Ops pi prompts stay **short**. This SKU is one 1M research stream;
  a second 1M ingest for “check the GPUs” is waste.

## Report-to-human path

Works when the model is dead:

```text
ssh root@"$SSH_HOST" -p "$SSH_PORT" cat /workspace/ops/LATEST.md
```

Works when the model is up: pi writes
`/workspace/ops/reports/YYYY-MM-DD-<slug>.md` with cause, evidence
(PromQL / nvidia-smi snippets), and a recommended human action
(stop the pod / restart boot / ignore / wait for download).

No outbound notify. The human is already SSHed or will be — this box
bills $8.36/hr; sitting on a dead serve without reading `LATEST.md` is
the failure mode, not missing Slack.

## Sources

- Pod UX sitting: [`../sessions/2026-09-03-pod-ux.md`](../sessions/2026-09-03-pod-ux.md)
- SGLang `/health` orphan bug: https://github.com/sgl-project/sglang/issues/35884
- CVE-2026-15977 / sglang#37457 (`/get_server_info` leaks `--api-key`)
- VictoriaMetrics query API: https://docs.victoriametrics.com/victoriametrics/single-server-victoriametrics/
- pi prompt templates: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/prompt-templates.md
- pi-debug-dashboard (rejected HTTP): https://github.com/ricoyudog/pi-debug-dashboard
- pi-telemetry local SQLite (optional): https://www.npmjs.com/package/@spences10/pi-telemetry
