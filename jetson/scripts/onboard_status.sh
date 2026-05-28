#!/usr/bin/env bash
set -euo pipefail

echo "== Network =="
hostname -I || true

echo "== Camera =="
"$(dirname "$0")/check_camera.sh" /dev/video0 640 480 30 || true

echo "== Python modules =="
python3 - <<'PY'
import importlib.util
for name in ["cv2", "numpy", "yaml", "tensorrt", "pymavlink"]:
    print(f"{name}: {'yes' if importlib.util.find_spec(name) else 'no'}")
PY

echo "== Services =="
systemctl --no-pager --full status vision-landing.service vision-dashboard.service 2>/dev/null || true
