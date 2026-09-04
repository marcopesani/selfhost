#!/usr/bin/env bash
# Run on the LAPTOP. Start the SSH tunnel and smoke /v1/models on :18000.
# Prefer MagicDNS glm-flash (Tailscale). Operator break-glass: SSH_HOST from .env.
# NEVER curl /get_server_info.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
OP_SOCK="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [[ -S "$OP_SOCK" ]] && { [[ -z "${SSH_AUTH_SOCK:-}" ]] || [[ ! -S "${SSH_AUTH_SOCK}" ]]; }; then
  export SSH_AUTH_SOCK="$OP_SOCK"
fi

LOCAL_PORT="${LOCAL_PORT:-18000}"
VM_LOCAL_PORT="${VM_LOCAL_PORT:-18428}"

if lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "glm-up: already listening on 127.0.0.1:${LOCAL_PORT}"
else
  echo "glm-up: starting tunnel (leave this job running, or rerun in another terminal)"
  # shellcheck disable=SC1091
  "$ROOT/scripts/ssh-tunnel.sh" "$@" &
  tunnel_pid=$!
  for _ in $(seq 1 40); do
    if lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
      break
    fi
    if ! kill -0 "$tunnel_pid" 2>/dev/null; then
      echo "glm-up: tunnel exited before bind" >&2
      wait "$tunnel_pid" || true
      exit 1
    fi
    sleep 0.25
  done
  if ! lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "glm-up: ${LOCAL_PORT} did not bind" >&2
    exit 1
  fi
  echo "glm-up: tunnel pid $tunnel_pid"
fi

if [[ -z "${GLM_API_KEY:-}" ]]; then
  echo "glm-up: set GLM_API_KEY to smoke" >&2
  exit 1
fi

code="$(curl -sS -o /tmp/glm-up-models.json -w '%{http_code}' --max-time 10 \
  -H "Authorization: Bearer ${GLM_API_KEY}" \
  "http://127.0.0.1:${LOCAL_PORT}/v1/models")"
echo "glm-up: GET /v1/models → ${code}  (base http://127.0.0.1:${LOCAL_PORT}/v1)"
python3 - <<'PY'
import json
from pathlib import Path
p=Path("/tmp/glm-up-models.json")
try:
    d=json.loads(p.read_text())
except Exception as e:
    print("glm-up: body not json", e)
    raise SystemExit(1)
ids=[m.get("id") for m in d.get("data") or d.get("models") or []]
print("glm-up: models", ids or d)
if "glm-5.3-flash" not in ids:
    raise SystemExit("glm-up: expected glm-5.3-flash")
PY
echo "glm-up: vmui http://127.0.0.1:${VM_LOCAL_PORT}/vmui (optional)"
echo "glm-up: do not curl Tailscale :8000 or /get_server_info"
if [[ -n "${tunnel_pid:-}" ]]; then
  echo "glm-up: waiting on tunnel (Ctrl-C stops it)"
  wait "$tunnel_pid"
fi
