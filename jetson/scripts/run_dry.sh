#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$PROJECT_ROOT/src:${PYTHONPATH:-}"

python3 -m vision_landing.main \
  --config "$PROJECT_ROOT/configs/default.yaml" \
  --camera-config "$PROJECT_ROOT/configs/camera.yaml" \
  --dry-run
