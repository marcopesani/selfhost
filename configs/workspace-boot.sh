#!/usr/bin/env bash
# Volume start hook (template: `/workspace/boot.sh &`). Overlay then SGLang.
# Do not exec overlay — Tailscale up must not block inference.
set -euo pipefail
if [[ -x /workspace/overlay.sh ]]; then
  install -d -m 700 /workspace/tailscale
  nohup /workspace/overlay.sh >>/workspace/tailscale/boot.log 2>&1 &
fi
exec /workspace/sglang-boot.sh
