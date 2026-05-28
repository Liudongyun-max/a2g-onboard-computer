#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

python3 tools/aruco_distance_gate.py \
  --dictionary "${ARUCO_DICTIONARY:-DICT_5X5_250}" \
  --marker-id "${ARUCO_MARKER_ID:-1}" \
  --marker-size-m "${ARUCO_MARKER_SIZE_M:-0.04268}" \
  --distance-m 1.50 \
  "$@"
