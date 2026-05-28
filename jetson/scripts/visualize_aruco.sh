#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$PROJECT_ROOT/src:${PYTHONPATH:-}"

ARGS=(
  --device "${ARUCO_DEVICE:-/dev/video0}"
  --dictionary "${ARUCO_DICTIONARY:-DICT_5X5_250}"
  --marker-id "${ARUCO_MARKER_ID:-1}"
  --marker-length-m "${ARUCO_MARKER_LENGTH_M:-0.04268}"
  --camera-config "${ARUCO_CAMERA_CONFIG:-$PROJECT_ROOT/configs/camera.yaml}"
)

if [[ -n "${ARUCO_KNOWN_DISTANCE_M:-}" ]]; then
  ARGS+=(--known-distance-m "$ARUCO_KNOWN_DISTANCE_M")
fi

python3 "$PROJECT_ROOT/tools/aruco_visualize.py" "${ARGS[@]}" "$@"
