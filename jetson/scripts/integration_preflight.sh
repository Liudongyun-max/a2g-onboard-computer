#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "== A2G integration preflight =="
date -Is

echo
echo "== Project root =="
pwd

echo
echo "== Network =="
hostname -I

echo
echo "== Services =="
systemctl --user --no-pager --full status vision-dashboard || true
systemctl --user --no-pager --full status vision-landing || true

echo
echo "== Ports =="
ss -ltnup | grep -E '(:8080|:5600|:14550)' || true

echo
echo "== Config safety gate =="
python3 - <<'PY'
from pathlib import Path
import yaml

config = yaml.safe_load(Path("configs/aruco_live.yaml").read_text()) or {}
mavlink_enabled = bool(config.get("mavlink", {}).get("enabled", False))
print("mavlink.enabled:", mavlink_enabled)
if mavlink_enabled:
    raise SystemExit("mavlink.enabled must remain false for phase-1/phase-2 ground integration")
PY

echo
echo "== Dashboard status =="
curl -s --max-time 3 http://127.0.0.1:8080/status
echo

echo
echo "== Ground command API self-test =="
python3 tools/ground_command_selftest.py --base-url http://127.0.0.1:8080

echo
echo "== Camera owner =="
fuser -v /dev/video0 /dev/video1 2>&1 || true

echo
echo "== Recent ground commands =="
tail -n 5 logs/ground_commands.jsonl 2>/dev/null || true

echo
echo "Preflight complete."
