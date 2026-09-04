#!/usr/bin/env bash
# Run on the LAPTOP. Copies overlay + boot wrapper onto the pod and starts Tailscale.
# Does not restart SGLang. Requires SSH_HOST/SSH_PORT in .env (break-glass TCP 22).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
if [[ -z "${SSH_HOST:-}" || -z "${SSH_PORT:-}" ]]; then
  echo "install-overlay: set SSH_HOST and SSH_PORT in .env" >&2
  exit 1
fi

SOCK="${SSH_AUTH_SOCK:-$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock}"
if [[ -S "$SOCK" ]]; then
  export SSH_AUTH_SOCK="$SOCK"
fi

ssh_pod() {
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    -p "$SSH_PORT" "root@$SSH_HOST" "$@"
}
scp_pod() {
  scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    -P "$SSH_PORT" "$@"
}

scp_pod \
  "$ROOT/configs/overlay.sh" \
  "$ROOT/configs/sglang-boot.sh" \
  "$ROOT/configs/workspace-boot.sh" \
  "root@$SSH_HOST:/tmp/"

# Auth key stays on the volume, never in the Runpod template env.
if [[ -f "$ROOT/secrets/tailscale.authkey" ]]; then
  ssh_pod 'install -d -m 700 /workspace/secrets'
  scp_pod "$ROOT/secrets/tailscale.authkey" "root@$SSH_HOST:/tmp/tailscale.authkey"
  ssh_pod 'install -m 600 /tmp/tailscale.authkey /workspace/secrets/tailscale.authkey && rm -f /tmp/tailscale.authkey'
fi

ssh_pod 'bash -s' <<'REMOTE'
set -euo pipefail
install -m 700 /tmp/overlay.sh /workspace/overlay.sh
install -m 700 /tmp/sglang-boot.sh /workspace/sglang-boot.sh
install -m 700 /tmp/workspace-boot.sh /workspace/boot.sh
rm -f /tmp/overlay.sh /tmp/sglang-boot.sh /tmp/workspace-boot.sh
set +e
TS_RESET=1 /workspace/overlay.sh
rc=$?
set -e
if [[ "$rc" -eq 2 ]]; then
  echo "install-overlay: daemon installed; auth key still required (exit 2 is expected)"
  exit 0
fi
exit "$rc"
REMOTE
