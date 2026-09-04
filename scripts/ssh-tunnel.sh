#!/usr/bin/env bash
# Run on the LAPTOP. Forwards local ports to the pod's localhost services.
# Prefer Tailscale hostname glm-flash once userspace Tailscale is up.
# Operator break-glass: SSH_HOST/SSH_PORT from .env (Runpod TCP 22).
# Do not curl the Tailscale IP:8000.
#
# Laptop binds 18000 / 18428 (ADR-028). Pod loopback stays 8000 / 8428.
# NEVER forward or scrape /get_server_info — it echoes the api key (CVE-2026-15977).
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
REMOTE_PORT="${REMOTE_PORT:-8000}"
VM_LOCAL_PORT="${VM_LOCAL_PORT:-18428}"
VM_REMOTE_PORT="${VM_REMOTE_PORT:-8428}"

pick_target() {
  if [[ -n "${1:-}" ]]; then
    echo "$1"
    return
  fi
  if command -v tailscale >/dev/null 2>&1; then
    if tailscale status --json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
peers=d.get("Peer") or {}
for p in peers.values():
    name=(p.get("HostName") or "").lower()
    dns=(p.get("DNSName") or "").lower()
    if p.get("Online") and ("glm-flash" in name or dns.startswith("glm-flash.")):
        sys.exit(0)
sys.exit(1)
'; then
      echo "glm-flash"
      return
    fi
  fi
  if [[ -n "${SSH_HOST:-}" ]]; then
    echo "runpod"
    return
  fi
  echo "glm-flash"
}

TARGET="$(pick_target "${1:-}")"
ARGS=(
  -N
  -o ExitOnForwardFailure=yes
  -o ServerAliveInterval=30
  -o BatchMode=yes
  -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}"
  -L "${VM_LOCAL_PORT}:127.0.0.1:${VM_REMOTE_PORT}"
)
if [[ "${GRAFANA:-0}" == "1" ]]; then
  ARGS+=( -L "${GRAFANA_LOCAL_PORT:-9300}:127.0.0.1:${GRAFANA_REMOTE_PORT:-9300}" )
fi

if [[ "$TARGET" == "runpod" ]]; then
  ARGS+=( -p "${SSH_PORT:?SSH_PORT unset}" )
  echo "ssh ${ARGS[*]} root@<runpod>   # break-glass TCP 22" >&2
  exec ssh "${ARGS[@]}" "root@${SSH_HOST}"
fi

# MagicDNS often fails in macOS getaddrinfo; tailscale nc resolves internally.
ARGS+=( -o "ProxyCommand=tailscale nc %h %p" )
echo "ssh ${ARGS[*]} root@glm-flash" >&2
exec ssh "${ARGS[@]}" "root@glm-flash"
