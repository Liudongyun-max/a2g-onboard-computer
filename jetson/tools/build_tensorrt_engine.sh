#!/usr/bin/env bash
set -euo pipefail

ONNX_PATH="${1:-models/landing_target.onnx}"
ENGINE_PATH="${2:-models/landing_target.engine}"

if ! command -v trtexec >/dev/null 2>&1; then
  echo "trtexec not found. Install TensorRT samples/bin package or add it to PATH." >&2
  exit 1
fi

trtexec \
  --onnx="$ONNX_PATH" \
  --saveEngine="$ENGINE_PATH" \
  --fp16 \
  --workspace=1024
