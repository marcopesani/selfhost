#!/usr/bin/env bash
# Run on the LAPTOP. Forwards local ports to the pod's localhost services.
# Prefer Tailscale hostname (Tailscale SSH) once userspace Tailscale is up.
# Do not curl the Tailscale IP:8000 — userspace netstack would hit localhost
# unless the ACL is :22 only. This script is the access method.
#
# Forwarded (all loopback on the pod):
#   8000  SGLang API (OpenAI /v1/chat/completions, /v1/responses; Anthropic /v1/messages)
#   8428  VictoriaMetrics vmui  -> http://127.0.0.1:8428/vmui
#
# Not forwarded (scraped in-pod only): 9835 nvidia_gpu_exporter, 9100 node_exporter.
# NEVER forward or scrape /get_server_info — it echoes the api key (CVE-2026-15977).
set -euo pipefail

HOST="${1:-glm-flash}"
LOCAL_PORT="${LOCAL_PORT:-8000}"
REMOTE_PORT="${REMOTE_PORT:-8000}"
VM_LOCAL_PORT="${VM_LOCAL_PORT:-8428}"
VM_REMOTE_PORT="${VM_REMOTE_PORT:-8428}"

ARGS=(
  -N
  -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}"
  -L "${VM_LOCAL_PORT}:127.0.0.1:${VM_REMOTE_PORT}"
)
# Optionally forward Grafana if installed in the pod (GRAFANA=1 scripts/ssh-tunnel.sh)
if [[ "${GRAFANA:-0}" == "1" ]]; then
  ARGS+=( -L "${GRAFANA_LOCAL_PORT:-9300}:127.0.0.1:${GRAFANA_REMOTE_PORT:-9300}" )
fi

echo "ssh ${ARGS[*]} root@${HOST}"
exec ssh "${ARGS[@]}" "root@${HOST}"
