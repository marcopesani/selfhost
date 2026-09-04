#!/usr/bin/env bash
# Runs ON the pod. Pulls ADR-010 weights onto the encrypted volume disk.
# Pin DFlash2 at 7d74cdd (do not float to latest).
set -euo pipefail
export PATH="/opt/sglang/bin:${PATH}"
if [[ -f /workspace/secrets/env ]]; then
  set -a
  # shellcheck disable=SC1091
  source /workspace/secrets/env
  set +a
fi
export HF_HOME="${HF_HOME:-/workspace/hf}"
export HF_XET_HIGH_PERFORMANCE=1
export HF_HUB_DISABLE_TELEMETRY=1

mkdir -p /workspace/logs /workspace/models
echo "START $(date -u +%Y-%m-%dT%H:%M:%SZ)"
hf download dealignai/GLM-5.3-Flash-UNCENSORED-NVFP4 \
  --local-dir /workspace/models/GLM-5.3-Flash-UNCENSORED-NVFP4
echo "NVFP4_DONE $(date -u +%Y-%m-%dT%H:%M:%SZ)"
hf download incoai/GLM-5.3-Flash-DFlash2 --revision 7d74cdd \
  --local-dir /workspace/models/GLM-5.3-Flash-DFlash2
echo "DFLASH_DONE $(date -u +%Y-%m-%dT%H:%M:%SZ)"
