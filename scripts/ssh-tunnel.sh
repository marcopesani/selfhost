#!/usr/bin/env bash
# Run on the LAPTOP. Forwards local 8000 to the pod's localhost API.
# Prefer Tailscale hostname (Tailscale SSH) once userspace Tailscale is up.
# Do not curl the Tailscale IP:8000 — userspace netstack would hit localhost
# unless the ACL is :22 only. This script is the access method.
set -euo pipefail

HOST="${1:-glm-flash}"
LOCAL_PORT="${LOCAL_PORT:-8000}"
REMOTE_PORT="${REMOTE_PORT:-8000}"

echo "ssh -N -L ${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT} root@${HOST}"
exec ssh -N -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" "root@${HOST}"
