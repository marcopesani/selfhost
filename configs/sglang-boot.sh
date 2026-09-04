#!/usr/bin/env bash
# Runs ON the pod. Template start command backgrounds this if it is executable.
# Bind loopback only. Do not scrape /get_server_info (CVE-2026-15977).
# ADR-025: 512k API window so usage can hit 100%. Do not advertise 1M on this image.
# MTP/EAGLE is off: this image dies on the NextN draft (sglang#36599, packed 2048 vs BF16 4096).
# Re-enable after #37322 or a patched image:
#   --speculative-algorithm EAGLE --speculative-num-steps 5 --speculative-eagle-topk 1 --speculative-num-draft-tokens 6
set -euo pipefail

export PATH="/opt/sglang/bin:/root/.cargo/bin:/usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}"
if [[ -f /workspace/secrets/env ]]; then
  set -a
  # shellcheck disable=SC1091
  source /workspace/secrets/env
  set +a
fi

export SGLANG_OPT_DEEPGEMM_HC_PRENORM="${SGLANG_OPT_DEEPGEMM_HC_PRENORM:-0}"
export SGLANG_ENABLE_JIT_DEEPGEMM="${SGLANG_ENABLE_JIT_DEEPGEMM:-0}"
export HF_HUB_DISABLE_TELEMETRY="${HF_HUB_DISABLE_TELEMETRY:-1}"
export NCCL_IB_DISABLE="${NCCL_IB_DISABLE:-1}"
export HF_HOME="${HF_HOME:-/workspace/hf}"
export HF_HUB_OFFLINE="${HF_HUB_OFFLINE:-1}"
export PYTHONUNBUFFERED=1
# Enable TF32 on SM120 instead of leaving float32 matmul on the slow path
# (torch/_inductor "TensorFloat32 tensor cores available but not enabled").
export TORCH_FLOAT32_MATMUL_PRECISION="${TORCH_FLOAT32_MATMUL_PRECISION:-high}"

MODEL="/workspace/models/GLM-5.3-Flash-UNCENSORED-NVFP4"
LOGDIR="/workspace/logs"
mkdir -p "$LOGDIR"
chmod 700 "$LOGDIR"

if [[ ! -f "$MODEL/config.json" ]]; then
  echo "sglang-boot: weights missing at $MODEL — skip"
  exit 0
fi
if [[ -z "${GLM_API_KEY:-}" ]]; then
  echo "sglang-boot: GLM_API_KEY unset — skip"
  exit 1
fi

# Container overlay is ephemeral. Re-apply volume patches before every launch.
if [[ -f /workspace/patches/apply_sglang_runtime.py ]]; then
  python /workspace/patches/apply_sglang_runtime.py
fi

exec >>"$LOGDIR/sglang.log" 2>&1
# `sglang serve` is the supported entrypoint; `python -m sglang.launch_server` warns.
exec sglang serve \
  --model-path "$MODEL" \
  --served-model-name glm-5.3-flash \
  --host 127.0.0.1 --port 8000 \
  --api-key "$GLM_API_KEY" \
  --tp-size 4 \
  --quantization modelopt_fp4 \
  --attention-backend dsa \
  --dsa-prefill-backend tilelang \
  --dsa-decode-backend tilelang \
  --moe-runner-backend flashinfer_cutlass \
  --kv-cache-dtype bfloat16 \
  --mem-fraction-static 0.85 \
  --disable-shared-experts-fusion \
  --disable-custom-all-reduce \
  --mm-attention-backend triton_attn \
  --reasoning-parser glm45 \
  --tool-call-parser glm47 \
  --context-length 524288 \
  --max-total-tokens 524288 \
  --max-prefill-tokens 131072 \
  --chunked-prefill-size 16384 \
  --preferred-sampling-params '{"max_new_tokens":65536}' \
  --enable-custom-logit-processor \
  --stream-response-default-include-usage \
  --trust-remote-code \
  --enable-metrics \
  --enable-mfu-metrics \
  --bucket-time-to-first-token 1 5 10 30 60 120 300 600 \
  --bucket-e2e-request-latency 1 5 10 30 60 120 300 600
