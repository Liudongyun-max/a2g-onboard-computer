#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/configs/env.local"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

export PYTHONPATH="${PYTHONPATH:-$PROJECT_ROOT/src}"

python3 -m vision_landing.main \
  --config "${VISION_LANDING_CONFIG:-$PROJECT_ROOT/configs/default.yaml}" \
  --camera-config "${VISION_LANDING_CAMERA_CONFIG:-$PROJECT_ROOT/configs/camera.yaml}"
