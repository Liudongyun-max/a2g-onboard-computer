#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$PROJECT_ROOT/src:${PYTHONPATH:-}"

python3 "$PROJECT_ROOT/tools/web_dashboard.py" \
  --host "${DASHBOARD_HOST:-0.0.0.0}" \
  --port "${DASHBOARD_PORT:-8080}" \
  --config "${VISION_LANDING_CONFIG:-$PROJECT_ROOT/configs/aruco_live.yaml}" \
  --camera-config "${VISION_LANDING_CAMERA_CONFIG:-$PROJECT_ROOT/configs/camera.yaml}" \
  --log-file "${DASHBOARD_LOG_FILE:-$PROJECT_ROOT/logs/dashboard_status.jsonl}" \
  --ground-command-log "${GROUND_COMMAND_LOG_FILE:-$PROJECT_ROOT/logs/ground_commands.jsonl}" \
  --event-log "${SYSTEM_EVENT_LOG_FILE:-$PROJECT_ROOT/logs/system_events.jsonl}"
