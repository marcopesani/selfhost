#!/usr/bin/env bash
# Run ON the pod. Userspace Tailscale — no TUN, no SOCKS, no Serve, no Funnel.
# Auth: TS_AUTHKEY or /workspace/secrets/tailscale.authkey (tagged tag:glm).
# State: /workspace/tailscale so stop/start keeps the same node.
set -euo pipefail

STATE_DIR="${STATE_DIR:-/workspace/tailscale}"
SOCKET="${SOCKET:-/var/run/tailscale/tailscaled.sock}"
HOSTNAME="${TS_HOSTNAME:-glm-flash}"
AUTH_FILE="${TS_AUTHKEY_FILE:-/workspace/secrets/tailscale.authkey}"

install -d -m 700 "$STATE_DIR"
if [[ -f /workspace/secrets/env ]]; then
  set -a
  # shellcheck disable=SC1091
  source /workspace/secrets/env
  set +a
fi
if [[ -z "${TS_AUTHKEY:-}" && -f "$AUTH_FILE" ]]; then
  TS_AUTHKEY="$(tr -d ' \n' <"$AUTH_FILE")"
  export TS_AUTHKEY
fi

if ! command -v tailscaled >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
# Package unit tries /dev/net/tun. This guest has neither TUN nor NET_ADMIN.
systemctl disable --now tailscaled 2>/dev/null || true
mkdir -p /etc/default
printf 'FLAGS="--tun=userspace-networking --statedir=%s"\n' "$STATE_DIR" >/etc/default/tailscaled

if ! pgrep -f '/usr/sbin/tailscaled' >/dev/null 2>&1; then
  nohup /usr/sbin/tailscaled \
    --tun=userspace-networking \
    --statedir="$STATE_DIR" \
    --socket="$SOCKET" \
    >>"$STATE_DIR/tailscaled.log" 2>&1 &
fi

for _ in $(seq 1 40); do
  [[ -S "$SOCKET" ]] && break
  sleep 0.25
done
if [[ ! -S "$SOCKET" ]]; then
  echo "overlay: tailscaled socket missing" >&2
  exit 1
fi

unset TS_SOCKS5_SERVER ALL_PROXY HTTP_PROXY HTTPS_PROXY

backend="$(tailscale --socket="$SOCKET" status --json 2>/dev/null || true)"
running=0
if [[ -n "$backend" ]] && printf '%s' "$backend" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get("BackendState")=="Running" else 1)'; then
  running=1
fi

up_args=(
  --socket="$SOCKET"
  up
  --ssh
  --hostname="$HOSTNAME"
  --accept-dns=false
  --advertise-exit-node=false
)
if [[ -n "${TS_AUTHKEY:-}" ]]; then
  up_args+=(--authkey="$TS_AUTHKEY" --advertise-tags=tag:glm)
fi
if [[ "${TS_RESET:-0}" == "1" ]]; then
  up_args+=(--reset)
fi

if [[ "$running" -eq 1 && -z "${TS_AUTHKEY:-}" ]]; then
  tailscale --socket="$SOCKET" status
  echo "overlay: already logged in. Reach the API with ssh -L, not a Tailscale IP:8000."
elif [[ -n "${TS_AUTHKEY:-}" || "$running" -eq 1 ]]; then
  tailscale "${up_args[@]}"
  tailscale --socket="$SOCKET" status
  echo "overlay: userspace up. Reach the API with ssh -L, not a Tailscale IP:8000."
else
  echo "overlay: tailscaled is up (userspace). Not logged in."
  echo "overlay: 1) paste configs/tailscale-acl.hujson at https://login.tailscale.com/admin/acls"
  echo "overlay: 2) create an auth key with tag:glm (reusable, not ephemeral)"
  echo "overlay: 3) write it to /workspace/secrets/tailscale.authkey and rerun /workspace/overlay.sh"
  exit 2
fi

serve_out="$(tailscale --socket="$SOCKET" serve status 2>/dev/null || true)"
if [[ -n "$serve_out" && "$serve_out" != "No serve config" ]]; then
  echo "overlay: refuse Tailscale serve — disable it" >&2
  echo "$serve_out" >&2
  exit 1
fi
