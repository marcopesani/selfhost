#!/usr/bin/env bash
# Run ON the pod (first boot via web SSH or TCP 22).
# Userspace Tailscale — Runpod has no /dev/net/tun.
# Do not start SOCKS, Serve, or Funnel. ACL on the tailnet must be :22 only
# (userspace netstack otherwise publishes every localhost TCP port).
set -euo pipefail

STATE_DIR="${STATE_DIR:-/workspace/tailscale}"
SOCKET="${SOCKET:-/var/run/tailscale/tailscaled.sock}"
HOSTNAME="${TS_HOSTNAME:-glm-flash}"

install -d -m 700 "$STATE_DIR"
if ! command -v tailscaled >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

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

# Flags are not remembered; repeat them every up.
# First boot: browser login URL so the pod is a user device.
# Tagged authkeys skip autogroup:self until SSH ACLs are written.
up_args=(
  --socket="$SOCKET"
  up
  --ssh
  --hostname="$HOSTNAME"
  --accept-dns=false
  --advertise-exit-node=false
  --reset
)
if [[ -n "${TS_AUTHKEY:-}" ]]; then
  up_args+=(--authkey="$TS_AUTHKEY")
fi
tailscale "${up_args[@]}"
tailscale --socket="$SOCKET" status
